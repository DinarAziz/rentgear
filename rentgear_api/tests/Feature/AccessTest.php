<?php

namespace Tests\Feature;

use App\Models\Rental;
use Tests\ApiTestCase;

class AccessTest extends ApiTestCase
{
    public function test_another_provider_cannot_touch_the_order(): void
    {
        // r-1 milik Arjuna Outdoor (Sari). Dewi punya toko lain.
        $this->as('dewi');
        foreach (['confirm', 'handover', 'return', 'complete'] as $action) {
            $this->assertApiError($this->postJson("/api/v1/rentals/r-1/$action"), 'FORBIDDEN', 403);
        }
        $this->assertApiError($this->postJson('/api/v1/rentals/r-1/reject', ['reason' => 'x']), 'FORBIDDEN', 403);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-1/guarantees/g-1/review', ['accept' => true]), 'FORBIDDEN', 403);

        $this->assertSame('pendingConfirmation', Rental::find('r-1')->status);
    }

    public function test_another_customer_cannot_pay_cancel_or_view(): void
    {
        $this->as('rina');
        $this->assertApiError($this->postJson('/api/v1/rentals/r-1/cancel', ['reason' => 'x']), 'FORBIDDEN', 403);
        $this->assertApiError($this->getJson('/api/v1/rentals/r-1'), 'FORBIDDEN', 403);
        $this->assertApiError(
            $this->post('/api/v1/rentals/r-1/payment', ['proof' => $this->photo()], ['Accept' => 'application/json']),
            'FORBIDDEN', 403);
    }

    public function test_the_renter_the_store_owner_and_the_admin_can_view_a_rental(): void
    {
        foreach (['budi', 'sari', 'admin'] as $who) {
            $this->as($who)->getJson('/api/v1/rentals/r-1')->assertOk()->assertJsonPath('data.invoiceCode', 'INV-DEMO-0001');
        }
        $this->assertApiError($this->as('dewi')->getJson('/api/v1/rentals/r-1'), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('admin')->getJson('/api/v1/rentals/r-tidak-ada'), 'NOT_FOUND', 404);
    }

    public function test_guarantee_photos_and_payment_proofs_are_private(): void
    {
        $rental = $this->book()->json('data');
        $guaranteeId = $rental['guarantees'][0]['id'];

        foreach (['budi', 'sari', 'admin'] as $who) {
            $this->as($who)->get("/api/v1/files/guarantees/$guaranteeId")->assertOk();
        }
        $this->assertApiError($this->as('rina')->getJson("/api/v1/files/guarantees/$guaranteeId"), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('dewi')->getJson("/api/v1/files/guarantees/$guaranteeId"), 'FORBIDDEN', 403);
        // Bukti transfer belum diunggah.
        $this->assertApiError($this->as('budi')->getJson("/api/v1/files/payments/{$rental['id']}"), 'NOT_FOUND', 404);
    }

    public function test_admin_only_endpoints_refuse_other_roles(): void
    {
        $this->assertApiError($this->as('budi')->getJson('/api/v1/customers'), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('sari')->putJson('/api/v1/providers/p-puncak/status', ['status' => 'verified']), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('budi')->putJson('/api/v1/customers/u-rina/blacklist', ['reason' => 'x']), 'FORBIDDEN', 403);
    }

    public function test_admin_verifies_a_store_and_its_gear_appears_in_the_catalog(): void
    {
        $this->as('admin')->putJson('/api/v1/providers/p-puncak/status', ['status' => 'verified'])
            ->assertOk()->assertJsonPath('data.status', 'verified');

        $ids = collect($this->as('budi')->getJson('/api/v1/equipment')->json('data'))->pluck('id');
        $this->assertContains('e-family6', $ids);
    }
}
