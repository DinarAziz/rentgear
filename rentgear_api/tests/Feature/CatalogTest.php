<?php

namespace Tests\Feature;

use App\Models\Equipment;
use Tests\ApiTestCase;

class CatalogTest extends ApiTestCase
{
    public function test_catalog_hides_inactive_gear_and_unverified_stores(): void
    {
        Equipment::find('e-kompor')->update(['is_active' => false]);

        $ids = collect($this->as('budi')->getJson('/api/v1/equipment')->assertOk()->json('data'))->pluck('id');

        $this->assertCount(7, $ids);
        $this->assertNotContains('e-kompor', $ids);   // disembunyikan penyedia
        $this->assertNotContains('e-family6', $ids);  // toko belum terverifikasi
    }

    public function test_search_matches_name_or_brand_and_filters_by_category(): void
    {
        $this->as('budi');
        $this->assertSame(['e-dome4'], collect($this->getJson('/api/v1/equipment?query=eiger')->json('data'))->pluck('id')->all());
        $this->assertEqualsCanonicalizing(['e-dome4', 'e-ul2p'],
            collect($this->getJson('/api/v1/equipment?categoryId=tenda')->json('data'))->pluck('id')->all());
    }

    public function test_equipment_json_matches_the_flutter_model(): void
    {
        $data = $this->as('budi')->getJson('/api/v1/equipment/e-sepatu')->assertOk()->json('data');

        $this->assertSame('p-semeru', $data['providerId']);
        $this->assertEquals(40000, $data['pricePerDay']);
        $this->assertSame(['label' => '39', 'stock' => 1], $data['sizes'][0]);
        $this->assertCount(3, $data['photos']);
        $this->assertStringEndsWith('/api/v1/media/equipment/sepatu_1.jpg', $data['photos'][0]['url']);
        $this->assertTrue($data['isActive']);
    }

    public function test_equipment_photos_are_public_but_nothing_else_is_served(): void
    {
        $this->get('/api/v1/media/equipment/sepatu_1.jpg')->assertOk()->assertHeader('Content-Type', 'image/jpeg');
        $this->assertApiError($this->getJson('/api/v1/media/equipment/tidak-ada.jpg'), 'NOT_FOUND', 404);
        $this->assertApiError($this->getJson('/api/v1/media/../.env'), 'NOT_FOUND', 404);
        $this->assertApiError($this->getJson('/api/v1/media/guarantees/x.jpg'), 'NOT_FOUND', 404);
    }

    public function test_unknown_equipment_is_not_found(): void
    {
        $this->assertApiError($this->as('budi')->getJson('/api/v1/equipment/tidak-ada'), 'NOT_FOUND', 404);
    }

    public function test_availability_uses_peak_occupancy(): void
    {
        // e-dome4 stok 3: r-1 memakai 1 unit hari +3..+5, r-2 memakai 2 unit hari +4..+6.
        $this->as('budi');
        $uri = fn (int $a, int $b) => "/api/v1/equipment/e-dome4/availability?start={$this->day($a)}&end={$this->day($b)}";

        $this->getJson($uri(1, 2))->assertJsonPath('data.available', 3);
        $this->getJson($uri(3, 3))->assertJsonPath('data.available', 2);
        $this->getJson($uri(4, 5))->assertJsonPath('data.available', 0);
        $this->getJson($uri(6, 8))->assertJsonPath('data.available', 1);
    }

    public function test_availability_is_tracked_per_size(): void
    {
        $data = $this->as('budi')
            ->getJson("/api/v1/equipment/e-sepatu/availability?start={$this->day(1)}&end={$this->day(2)}")
            ->assertOk()->json('data');

        $this->assertSame(9, $data['available']);
        $this->assertSame(2, $data['sizes']['41']);
        $this->assertSame(1, $data['sizes']['44']);
    }
}
