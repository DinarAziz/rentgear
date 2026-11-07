<?php

namespace Tests\Feature;

use App\Models\Rental;
use App\Models\User;
use Laravel\Sanctum\Sanctum;
use Tests\ApiTestCase;

class HandoverCodeTest extends ApiTestCase
{
    public function test_only_the_renter_sees_the_code_and_a_wrong_code_is_refused(): void
    {
        // r-3 sudah dibayar, milik toko Sari.
        $rental = Rental::findOrFail('r-3');
        Sanctum::actingAs(User::findOrFail($rental->customer_id));
        $this->getJson('/api/v1/rentals/r-3')->assertJsonPath('data.handoverCode', $rental->handover_code);

        $this->as('sari')->getJson('/api/v1/rentals/r-3')->assertJsonPath('data.handoverCode', null);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-3/handover', ['code' => '999999x']), 'HANDOVER_CODE_INVALID', 422);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-3/handover'), 'VALIDATION', 422);
        $this->assertSame('paid', $rental->fresh()->status);
    }

    public function test_the_code_changes_after_pickup_so_it_cannot_be_reused_for_the_return(): void
    {
        $old = $this->code('r-3');
        $this->as('sari')->postJson('/api/v1/rentals/r-3/handover', ['code' => $old])->assertJsonPath('data.status', 'pickedUp');

        $this->assertNotSame($old, $this->code('r-3'));
        $this->assertApiError($this->postJson('/api/v1/rentals/r-3/return', ['code' => $old]), 'HANDOVER_CODE_INVALID', 422);
        $this->postJson('/api/v1/rentals/r-3/return', ['code' => $this->code('r-3')])->assertJsonPath('data.status', 'returned');
    }
}
