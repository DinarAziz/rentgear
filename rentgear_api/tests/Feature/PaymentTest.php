<?php

namespace Tests\Feature;

use App\Models\Payment;
use App\Models\Rental;
use App\Support\ApiException;
use Illuminate\Support\Facades\Storage;
use Tests\ApiTestCase;

/** Pembayaran sebagai kelas sendiri: satu baris per bukti transfer, dengan nominal yang dikunci server. */
class PaymentTest extends ApiTestCase
{
    private function pay()
    {
        return $this->as('rina')->post('/api/v1/rentals/r-2/payment', ['proof' => $this->photo()], ['Accept' => 'application/json']);
    }

    public function test_each_proof_is_kept_with_the_amount_due(): void
    {
        $data = $this->pay()->assertOk()->json('data');

        // Tenda dome 45.000 x 2 unit x 3 hari + deposit 100.000 x 2 unit.
        $this->assertCount(1, $data['payments']);
        $this->assertEquals(470000, $data['payments'][0]['amount']);
        $this->assertSame('submitted', $data['payments'][0]['status']);
        $this->assertTrue($data['payments'][0]['hasProof']);
        $this->assertEquals(470000, Rental::findOrFail('r-2')->amountDue());
    }

    public function test_a_rejected_proof_stays_in_the_history_and_is_not_overwritten(): void
    {
        $this->pay()->assertOk();
        $first = Rental::findOrFail('r-2')->latestPayment();
        $this->as('sari')->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => false, 'reason' => 'Nominal kurang'])->assertOk();

        $data = $this->pay()->assertOk()->json('data');
        $this->assertSame(['rejected', 'submitted'], array_column($data['payments'], 'status'));
        $this->assertSame('Nominal kurang', $data['payments'][0]['note']);
        $this->assertSame('Arjuna Outdoor', $data['payments'][0]['reviewedBy']);
        Storage::disk('local')->assertExists($first->fresh()->proof_path);

        $this->as('sari')->postJson('/api/v1/rentals/r-2/payment-review', ['accept' => true])->assertOk()
            ->assertJsonPath('data.payments.1.status', 'accepted')->assertJsonPath('data.payments.0.status', 'rejected');
    }

    public function test_each_proof_can_be_opened_by_the_parties_only(): void
    {
        $this->pay()->assertOk();
        $id = Rental::findOrFail('r-2')->latestPayment()->id;

        $this->as('sari')->get("/api/v1/files/payments/r-2/$id")->assertOk();
        // Tanpa id pembayaran: bukti terakhir, untuk APK lama.
        $this->get('/api/v1/files/payments/r-2')->assertOk();
        $this->assertApiError($this->as('budi')->getJson("/api/v1/files/payments/r-2/$id"), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('rina')->getJson('/api/v1/files/payments/r-2/bukan-id'), 'NOT_FOUND', 404);
    }

    public function test_a_payment_is_decided_once(): void
    {
        $this->pay()->assertOk();
        $payment = Rental::findOrFail('r-2')->latestPayment();
        $payment->review(true, 'Arjuna Outdoor');

        $this->expectException(ApiException::class);
        $payment->review(false, 'Arjuna Outdoor', 'Ganti pikiran');
    }

    public function test_the_amount_follows_the_locked_discount(): void
    {
        Rental::whereKey('r-2')->update(['discount_percent' => 10]);
        $this->pay()->assertOk();

        // Diskon hanya memotong biaya sewa: 270.000 - 27.000 + deposit 200.000.
        $this->assertSame(443000.0, Payment::firstOrFail()->amount);
    }
}
