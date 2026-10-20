<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

class DiscountPolicyTest extends ApiTestCase
{
    public function test_a_store_sets_its_discount_within_the_platform_limit(): void
    {
        $this->as('budi')->getJson('/api/v1/providers/p-arjuna')->assertJsonPath('data.discountPolicy.longPercent', 0);
        $this->assertApiError($this->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 10, 'longPercent' => 20]), 'FORBIDDEN', 403);

        $this->as('sari')->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 10, 'longPercent' => 20])->assertOk()
            ->assertJsonPath('data.discountPolicy.shortPercent', 10)->assertJsonPath('data.discountPolicy.longPercent', 20);
        $this->getJson('/api/v1/providers/p-semeru')->assertJsonPath('data.discountPolicy.shortPercent', 0);

        $response = $this->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 10, 'longPercent' => 60]);
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertStringContainsString('50 persen', $response->json('error.message'));
        $this->assertApiError($this->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 30, 'longPercent' => 20]), 'VALIDATION', 422);
    }

    public function test_a_rental_keeps_the_discount_it_was_booked_under(): void
    {
        $this->as('sari')->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 10, 'longPercent' => 20])->assertOk();

        // Dua hari: belum dapat diskon. Tiga hari: 10%.
        $this->book()->assertOk()->assertJsonPath('data.discountPercent', 0);
        $id = $this->book(['startDate' => $this->day(5), 'endDate' => $this->day(7)], 'k2')->assertOk()
            ->assertJsonPath('data.discountPercent', 10)->json('data.id');

        // Toko mengubah diskonnya; sewa yang sudah dipesan tidak ikut berubah.
        $this->as('sari')->putJson('/api/v1/provider/discount-policy', ['shortPercent' => 0, 'longPercent' => 0])->assertOk();
        $this->as('budi')->getJson("/api/v1/rentals/$id")->assertJsonPath('data.discountPercent', 10);
    }
}
