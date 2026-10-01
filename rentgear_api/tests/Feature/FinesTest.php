<?php

namespace Tests\Feature;

use App\Models\Rental;
use Tests\ApiTestCase;

/** Kasus yang sama dengan grup "denda pada transaksi" di rentgear_app/test/fines_test.dart. */
class FinesTest extends ApiTestCase
{
    private float $deposit;

    protected function setUp(): void
    {
        parent::setUp();
        // Data demo dibuat 4 hari lalu, jadi r-4 (Budi, tenda ultralight) sudah lewat 3 hari.
        $this->afterDays(4);
        $this->deposit = Rental::find('r-4')->depositTotal();
    }

    public function test_late_three_days_fee_is_charged_on_return_using_the_server_date(): void
    {
        $this->assertSame('overdue', Rental::find('r-4')->status);

        // Tanggal kembali yang dikirim aplikasi diabaikan: server memakai tanggalnya sendiri.
        $data = $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', ['returnedAt' => $this->day(-3)])
            ->assertOk()->json('data');

        $this->assertSame('returned', $data['status']);
        $this->assertSame('good', $data['returnCondition']);
        $this->assertEquals(3 * 60000 * 1 * 1.5, $data['lateFee']);
        $this->assertEquals(0, $data['damageFee']);
        $this->assertSame('none', $data['damageReview']);
        $this->assertSame('Kondisi alat: Baik. Terlambat 3 hari', end($data['logs'])['note']);
    }

    public function test_small_damage_fee_applies_at_once_and_the_rental_can_be_closed(): void
    {
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', [
            'condition' => 'minorDamage', 'damageFee' => $this->deposit * 0.2, 'damageNote' => ' Pasak bengkok ',
        ])->assertOk()
            ->assertJsonPath('data.damageReview', 'none')
            ->assertJsonPath('data.damageNote', 'Pasak bengkok');

        $this->assertEquals($this->deposit * 0.2, Rental::find('r-4')->damage_fee);
        $this->postJson('/api/v1/rentals/r-4/complete')->assertJsonPath('data.status', 'completed');
    }

    public function test_invalid_damage_fee_is_refused(): void
    {
        $this->as('dewi');
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/return', ['condition' => 'good', 'damageFee' => 10000]), 'VALIDATION', 422);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/return', ['condition' => 'lost', 'damageFee' => $this->deposit + 1]), 'VALIDATION', 422);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/return', ['condition' => 'meledak']), 'VALIDATION', 422);
        $this->assertSame('overdue', Rental::find('r-4')->status);
    }

    public function test_large_fee_waits_for_the_admin_before_the_rental_can_be_closed(): void
    {
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', [
            'condition' => 'majorDamage', 'damageFee' => $this->deposit * 0.8, 'damageNote' => 'Flysheet sobek',
        ])->assertJsonPath('data.damageReview', 'pending')
            ->assertJsonPath('data.reviewReason', 'Denda kerusakan lebih dari separuh deposit.');
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/complete'), 'DAMAGE_REVIEW_PENDING', 409);

        // Hanya admin yang memutuskan, dan nominalnya tetap dibatasi deposit.
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/damage-decision', ['amount' => 0]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('admin')->postJson('/api/v1/rentals/r-4/damage-decision', ['amount' => $this->deposit + 1]), 'VALIDATION', 422);

        $this->postJson('/api/v1/rentals/r-4/damage-decision', ['amount' => $this->deposit * 0.4, 'note' => 'Sobekan kecil'])
            ->assertOk()->assertJsonPath('data.damageReview', 'decided')->assertJsonPath('data.reviewNote', 'Sobekan kecil');
        $this->assertEquals($this->deposit * 0.4, Rental::find('r-4')->damage_fee);

        $this->as('dewi')->postJson('/api/v1/rentals/r-4/complete')->assertJsonPath('data.status', 'completed');
    }

    public function test_customer_can_object_to_a_damage_fee(): void
    {
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', [
            'condition' => 'minorDamage', 'damageFee' => $this->deposit * 0.3, 'damageNote' => 'Resleting macet',
        ])->assertOk();

        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/damage-objection', ['reason' => 'bukan saya']), 'FORBIDDEN', 403);
        $data = $this->as('budi')->postJson('/api/v1/rentals/r-4/damage-objection', ['reason' => 'Resleting sudah macet sejak awal'])
            ->assertOk()->json('data');
        $this->assertSame('pending', $data['damageReview']);
        $this->assertStringContainsString('Resleting sudah macet', $data['reviewReason']);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-4/damage-objection', ['reason' => 'lagi']), 'INVALID_STATE', 409);
    }

    public function test_decision_without_a_pending_review_is_refused(): void
    {
        $response = $this->as('admin')->postJson('/api/v1/rentals/r-5/damage-decision', ['amount' => 0]);
        $this->assertApiError($response, 'INVALID_STATE', 409);
    }
}
