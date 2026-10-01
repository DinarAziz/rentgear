<?php

namespace Tests\Feature;

use App\Models\Equipment;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\ApiTestCase;

class EquipmentTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    private function save(array $overrides = [], ?string $id = null, string $who = 'sari'): TestResponse
    {
        $payload = array_replace([
            'categoryId' => 'tenda', 'name' => 'Tenda Baru', 'brand' => 'Consina', 'description' => 'Tes',
            'pricePerDay' => 30000, 'depositAmount' => 50000, 'weightGram' => 2000, 'stock' => 2,
            'photoOrder' => ['new:0'], 'newPhotos' => [$this->photo()],
        ], $overrides);

        return $this->as($who)->post('/api/v1/equipment'.($id === null ? '' : "/$id"), $payload, ['Accept' => 'application/json']);
    }

    public function test_new_equipment_needs_a_photo_and_appears_in_the_catalog(): void
    {
        $response = $this->save(['photoOrder' => [], 'newPhotos' => []]);
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertStringContainsString('minimal 1 foto', $response->json('error.message'));

        $data = $this->save()->assertOk()->json('data');
        $this->assertSame('p-arjuna', $data['providerId']);
        $this->assertCount(1, $data['photos']);
        $this->assertEquals(0, $data['rating']);
        $this->assertSame(100, $data['conditionScore']);

        $ids = collect($this->as('budi')->getJson('/api/v1/equipment')->json('data'))->pluck('id');
        $this->assertContains($data['id'], $ids);
    }

    public function test_shoes_must_have_sizes_and_hidden_items_leave_the_catalog(): void
    {
        $response = $this->save(['categoryId' => 'sepatu']);
        $this->assertStringContainsString('minimal satu ukuran', $response->json('error.message'));

        $data = $this->save([
            'categoryId' => 'sepatu', 'stock' => 99, 'isActive' => false,
            'sizes' => [['label' => '40', 'stock' => 1], ['label' => '41', 'stock' => 2]],
        ])->assertOk()->json('data');
        $this->assertSame(0, $data['stock']); // stok alat berukuran hanya dari daftar ukuran
        $this->assertSame([['label' => '40', 'stock' => 1], ['label' => '41', 'stock' => 2]], $data['sizes']);

        $ids = collect($this->as('budi')->getJson('/api/v1/equipment')->json('data'))->pluck('id');
        $this->assertNotContains($data['id'], $ids);
    }

    public function test_validation_messages_match_the_flutter_rules(): void
    {
        $message = $this->save([
            'name' => 'ab', 'pricePerDay' => 0, 'depositAmount' => -1, 'stock' => 0,
            'sizes' => [['label' => '40', 'stock' => 0], ['label' => '40', 'stock' => 0]],
        ])->json('error.message');

        foreach (['minimal 3 huruf', 'lebih dari 0', 'Deposit tidak boleh negatif', 'Ukuran 40 tercantum dua kali', 'Stok total minimal 1'] as $needle) {
            $this->assertStringContainsString($needle, $message);
        }
    }

    public function test_provider_cannot_edit_another_stores_equipment(): void
    {
        $this->assertApiError($this->save(id: 'e-ul2p'), 'FORBIDDEN', 403);
        $this->assertApiError($this->save(who: 'budi'), 'FORBIDDEN', 403);
        $this->assertSame('Tenda Ultralight 2 Orang', Equipment::find('e-ul2p')->name);
    }

    public function test_editing_keeps_reorders_and_adds_photos(): void
    {
        $data = $this->save([
            'name' => 'Tenda Dome 4 Orang (baru)', 'pricePerDay' => 50000,
            'photoOrder' => ['keep:e-dome4-photo-3', 'new:0', 'keep:e-dome4-photo-1', 'keep:e-ul2p-photo-1'],
        ], 'e-dome4')->assertOk()->json('data');

        $this->assertSame('Tenda Dome 4 Orang (baru)', $data['name']);
        $this->assertEquals(50000, $data['pricePerDay']);
        $this->assertEquals(4.7, $data['rating']); // rating tidak ikut diubah form
        // Foto 2 dihapus, foto toko lain diabaikan, urutan mengikuti kiriman.
        $this->assertCount(3, $data['photos']);
        $this->assertSame('e-dome4-photo-3', $data['photos'][0]['id']);
        $this->assertSame('e-dome4-photo-1', $data['photos'][2]['id']);
    }

    public function test_provider_updates_its_guarantee_policy(): void
    {
        $this->as('sari')->putJson('/api/v1/provider/guarantee-policy', [
            'acceptedTypes' => ['ktp', 'ktm'], 'baseRequired' => 1, 'highValueRequired' => 2, 'highValueThreshold' => 500000,
        ])->assertOk()->assertJsonPath('data.policy.acceptedTypes', ['ktp', 'ktm'])
            ->assertJsonPath('data.policy.highValueThreshold', 500000);

        $this->assertApiError($this->putJson('/api/v1/provider/guarantee-policy', [
            'acceptedTypes' => [], 'baseRequired' => 1, 'highValueRequired' => 2, 'highValueThreshold' => 500000,
        ]), 'VALIDATION', 422);
        $response = $this->putJson('/api/v1/provider/guarantee-policy', [
            'acceptedTypes' => ['ktp'], 'baseRequired' => 1, 'highValueRequired' => 2, 'highValueThreshold' => 500000,
        ]);
        $this->assertStringContainsString('lebih sedikit', $response->json('error.message'));
        $this->assertApiError($this->as('budi')->putJson('/api/v1/provider/guarantee-policy', [
            'acceptedTypes' => ['ktp'], 'baseRequired' => 1, 'highValueRequired' => 1, 'highValueThreshold' => 1,
        ]), 'FORBIDDEN', 403);
    }
}
