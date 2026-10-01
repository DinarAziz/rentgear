<?php

namespace Tests\Feature;

use App\Models\Equipment;
use Tests\ApiTestCase;

class StoreTest extends ApiTestCase
{
    public function test_store_rating_is_the_average_of_its_reviews(): void
    {
        $this->as('budi');
        $reviews = $this->getJson('/api/v1/providers/p-arjuna/reviews')->assertOk()->json('data');
        $store = $this->getJson('/api/v1/providers/p-arjuna')->assertOk()->json('data');

        $this->assertCount(3, $reviews);
        $this->assertSame(3, $store['reviewCount']);
        $this->assertEqualsWithDelta(collect($reviews)->avg('rating'), $store['rating'], 0.001);
        // Ulasan terbaru tampil lebih dulu.
        $this->assertGreaterThanOrEqual($reviews[1]['at'], $reviews[0]['at']);

        $puncak = $this->getJson('/api/v1/providers/p-puncak')->json('data');
        $this->assertSame(0, $puncak['reviewCount']);
        $this->assertEquals(0, $puncak['rating']);
    }

    public function test_store_json_carries_location_and_guarantee_policy(): void
    {
        $store = $this->as('budi')->getJson('/api/v1/providers/p-semeru')->json('data');

        $this->assertEqualsWithDelta(-8.1049, $store['latitude'], 0.0001);
        $this->assertEqualsWithDelta(113.0868, $store['longitude'], 0.0001);
        $this->assertSame(['ktp', 'ktm', 'ijazah', 'paspor'], $store['policy']['acceptedTypes']);
        $this->assertEquals(750000, $store['policy']['highValueThreshold']);
    }

    public function test_follow_and_unfollow_change_the_follower_count(): void
    {
        $this->as('budi');
        $before = $this->getJson('/api/v1/providers/p-semeru')->json('data.followerCount');
        $this->assertNotContains('p-semeru', $this->getJson('/api/v1/me/follows')->json('data'));

        $this->putJson('/api/v1/providers/p-semeru/follow')->assertOk()->assertJsonPath('data.followerCount', $before + 1);
        // Mengikuti dua kali tidak menambah hitungan.
        $this->putJson('/api/v1/providers/p-semeru/follow')->assertJsonPath('data.followerCount', $before + 1);
        $this->assertContains('p-semeru', $this->getJson('/api/v1/me/follows')->json('data'));

        $this->deleteJson('/api/v1/providers/p-semeru/follow')->assertJsonPath('data.followerCount', $before);
    }

    public function test_only_customers_can_follow_and_the_store_must_exist(): void
    {
        $this->assertApiError($this->as('sari')->putJson('/api/v1/providers/p-semeru/follow'), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('budi')->putJson('/api/v1/providers/p-tidak-ada/follow'), 'NOT_FOUND', 404);
    }

    public function test_store_equipment_includes_hidden_items(): void
    {
        Equipment::find('e-kompor')->update(['is_active' => false]);
        $ids = collect($this->as('sari')->getJson('/api/v1/providers/p-arjuna/equipment')->json('data'))->pluck('id');
        $this->assertContains('e-kompor', $ids);
        $this->assertCount(4, $ids);
    }
}
