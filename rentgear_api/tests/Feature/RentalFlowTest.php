<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Storage;
use Tests\ApiTestCase;

class RentalFlowTest extends ApiTestCase
{
    public function test_full_lifecycle_guarantee_verified_held_then_returned(): void
    {
        $rental = $this->book()->json('data');
        $id = $rental['id'];
        $guaranteeId = $rental['guarantees'][0]['id'];

        // Konfirmasi ditolak selama jaminan belum diverifikasi.
        $this->assertApiError($this->as('sari')->postJson("/api/v1/rentals/$id/confirm"), 'INVALID_TRANSITION', 409);

        $this->postJson("/api/v1/rentals/$id/guarantees/$guaranteeId/review", ['accept' => true])
            ->assertOk()->assertJsonPath('data.guarantees.0.status', 'verified');
        $this->postJson("/api/v1/rentals/$id/confirm")->assertJsonPath('data.status', 'awaitingPayment');

        $this->as('budi')->post("/api/v1/rentals/$id/payment", ['proof' => $this->photo()], ['Accept' => 'application/json'])
            ->assertOk()->assertJsonPath('data.status', 'paymentReview')->assertJsonPath('data.hasPaymentProof', true);
        Storage::disk('local')->assertExists("payments/$id.jpg");

        // Bukti belum diperiksa, jadi alat belum bisa diserahkan.
        $this->assertApiError($this->as('sari')->postJson("/api/v1/rentals/$id/handover"), 'INVALID_STATE', 409);
        $this->postJson("/api/v1/rentals/$id/payment-review", ['accept' => true])->assertJsonPath('data.status', 'paid');

        $this->as('sari')->postJson("/api/v1/rentals/$id/handover")
            ->assertJsonPath('data.status', 'pickedUp')->assertJsonPath('data.guarantees.0.status', 'held');
        $this->postJson("/api/v1/rentals/$id/return")
            ->assertJsonPath('data.status', 'returned')->assertJsonPath('data.returnCondition', 'good');
        $done = $this->postJson("/api/v1/rentals/$id/complete")->assertOk()->json('data');

        $this->assertSame('completed', $done['status']);
        $this->assertSame('returned', $done['guarantees'][0]['status']);
        $this->assertSame(
            ['pendingConfirmation', 'awaitingPayment', 'paymentReview', 'paid', 'pickedUp', 'returned', 'completed'],
            array_column($done['logs'], 'to'),
        );
        $this->assertSame('Arjuna Outdoor', $done['logs'][1]['actorName']);
        $this->assertSame('Budi Santoso', $done['logs'][2]['actorName']);
    }

    public function test_a_rejected_payment_proof_goes_back_to_the_renter_who_can_upload_again(): void
    {
        $pay = fn () => $this->as('rina')->post('/api/v1/rentals/r-2/payment', ['proof' => $this->photo()], ['Accept' => 'application/json']);
        $pay()->assertJsonPath('data.status', 'paymentReview');

        // Hanya toko pemilik pesanan yang memeriksa, dan penolakan wajib beralasan.
        $this->assertApiError($this->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => true]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('dewi')->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => true]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('sari')->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => false]), 'VALIDATION', 422);

        $rejected = $this->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => false, 'reason' => 'Nominal kurang'])
            ->assertJsonPath('data.status', 'awaitingPayment')->json('data');
        $this->assertSame('Bukti transfer ditolak: Nominal kurang', end($rejected['logs'])['note']);
        // Tidak ada bukti yang menunggu, jadi tidak ada yang bisa diterima.
        $this->assertApiError($this->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => true]), 'INVALID_TRANSITION', 409);
        // Stok tetap terkunci selama menunggu bukti baru.
        $this->getJson("/api/v1/equipment/e-dome4/availability?start={$this->day(4)}&end={$this->day(4)}")
            ->assertJsonPath('data.available', 0);

        $pay()->assertJsonPath('data.status', 'paymentReview');
        $this->as('sari')->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => true])->assertJsonPath('data.status', 'paid');
    }

    public function test_rejected_guarantee_blocks_confirmation_and_the_booking_can_be_rejected(): void
    {
        $this->as('sari')->postJson('/api/v1/rentals/r-1/guarantees/g-1/review', ['accept' => false, 'note' => 'Foto buram'])
            ->assertJsonPath('data.guarantees.0.status', 'rejected')->assertJsonPath('data.guarantees.0.note', 'Foto buram');
        $this->assertApiError($this->postJson('/api/v1/rentals/r-1/confirm'), 'INVALID_TRANSITION', 409);

        $this->postJson('/api/v1/rentals/r-1/reject', ['reason' => 'Jaminan tidak valid'])
            ->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.cancelReason', 'Jaminan tidak valid');

        // Stok dilepas: tanggal yang sama bisa dipesan lagi.
        $this->as('budi')->getJson("/api/v1/equipment/e-dome4/availability?start={$this->day(3)}&end={$this->day(3)}")
            ->assertJsonPath('data.available', 3);
    }

    public function test_customer_can_cancel_before_paying(): void
    {
        $this->as('rina')->postJson('/api/v1/rentals/r-2/cancel', ['reason' => 'Batal berangkat'])
            ->assertJsonPath('data.status', 'cancelled');
        $this->assertApiError($this->postJson('/api/v1/rentals/r-3/cancel', ['reason' => 'x']), 'INVALID_TRANSITION', 409);
    }

    public function test_handover_requires_payment_first(): void
    {
        $this->assertApiError($this->as('sari')->postJson('/api/v1/rentals/r-2/handover'), 'INVALID_STATE', 409);
    }

    public function test_guarantees_can_only_be_reviewed_before_confirmation(): void
    {
        $response = $this->as('sari')->postJson('/api/v1/rentals/r-2/guarantees/g-2/review', ['accept' => true]);
        $this->assertApiError($response, 'INVALID_STATE', 409);
    }

    public function test_each_role_lists_only_its_own_rentals(): void
    {
        $ids = fn (string $who) => collect($this->as($who)->getJson('/api/v1/rentals')->assertOk()->json('data'))->pluck('id')->sort()->values()->all();

        $this->assertSame(['r-1', 'r-4', 'r-5'], $ids('budi'));
        $this->assertSame(['r-1', 'r-2', 'r-3', 'r-5'], $ids('sari'));
        $this->assertSame(['r-4', 'r-6'], $ids('dewi'));
        $this->assertCount(6, $ids('admin'));
    }
}
