<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

class RescheduleTest extends ApiTestCase
{
    /** Booking kompor Budi untuk hari ke-1 sampai ke-2, lalu permintaan pindah tanggal. */
    private function ask(string $id, int $from, int $to)
    {
        return $this->as('budi')->postJson("/api/v1/rentals/$id/reschedule", ['startDate' => $this->day($from), 'endDate' => $this->day($to)]);
    }

    public function test_new_dates_apply_only_after_the_store_agrees(): void
    {
        $id = $this->book()->json('data.id');

        $this->ask($id, 5, 6)->assertOk()
            ->assertJsonPath('data.startDate', $this->day(1))
            ->assertJsonPath('data.rescheduleStart', $this->day(5))
            ->assertJsonPath('data.rescheduleEnd', $this->day(6));
        // Satu permintaan dalam satu waktu.
        $this->assertApiError($this->ask($id, 7, 8), 'INVALID_STATE', 409);

        // Hanya toko pemilik pesanan yang menjawab.
        $this->assertApiError($this->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => true]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('dewi')->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => true]), 'FORBIDDEN', 403);

        $done = $this->as('sari')->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => true])->assertOk()->json('data');
        $this->assertSame([$this->day(5), $this->day(6), null], [$done['startDate'], $done['endDate'], $done['rescheduleStart']]);
        $this->assertSame('pendingConfirmation', $done['status']);
        $this->assertStringStartsWith('Tanggal sewa diganti menjadi', end($done['logs'])['note']);
        $this->assertApiError($this->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => true]), 'INVALID_STATE', 409);
    }

    public function test_a_refused_request_keeps_the_old_dates(): void
    {
        $id = $this->book()->json('data.id');
        $this->ask($id, 5, 6)->assertOk();

        $this->assertApiError($this->as('sari')->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => false]), 'VALIDATION', 422);
        $kept = $this->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => false, 'reason' => 'Toko tutup'])->json('data');

        $this->assertSame([$this->day(1), null], [$kept['startDate'], $kept['rescheduleStart']]);
        $this->assertSame('Ganti tanggal ditolak: Toko tutup', end($kept['logs'])['note']);
    }

    public function test_the_rental_cannot_get_longer_move_to_the_past_or_stay_the_same(): void
    {
        $id = $this->book()->json('data.id');

        $this->assertApiError($this->ask($id, 5, 7), 'INVALID_DATE', 422);
        $this->assertApiError($this->ask($id, 6, 5), 'INVALID_DATE', 422);
        $this->assertApiError($this->ask($id, 1, 2), 'INVALID_DATE', 422);
        $this->assertApiError($this->ask($id, -3, -2), 'INVALID_DATE', 422);
        $this->assertApiError($this->as('rina')->postJson("/api/v1/rentals/$id/reschedule", ['startDate' => $this->day(5), 'endDate' => $this->day(6)]), 'FORBIDDEN', 403);
    }

    public function test_dates_taken_by_another_renter_are_refused_at_request_and_at_approval(): void
    {
        $id = $this->book()->json('data.id');
        // Keempat kompor disewa orang lain pada hari ke-5 sampai ke-6.
        $this->book(['qty' => 4, 'startDate' => $this->day(5), 'endDate' => $this->day(6)], 'k2')->assertOk();
        $this->assertApiError($this->ask($id, 5, 6), 'SLOT_UNAVAILABLE', 409);

        // Bergeser satu hari di atas tanggalnya sendiri boleh: sewa ini tidak menghalangi dirinya.
        $this->ask($id, 2, 3)->assertOk();
        // Stok habis setelah permintaan dibuat, sebelum toko menjawab.
        $this->book(['qty' => 3, 'startDate' => $this->day(3), 'endDate' => $this->day(3)], 'k3')->assertOk();
        $this->book(['qty' => 1, 'startDate' => $this->day(3), 'endDate' => $this->day(3)], 'k4')->assertOk();
        $this->assertApiError($this->as('sari')->postJson("/api/v1/rentals/$id/reschedule-review", ['accept' => true]), 'SLOT_UNAVAILABLE', 409);
        $this->as('budi')->getJson("/api/v1/rentals/$id")->assertJsonPath('data.startDate', $this->day(1));
    }

    public function test_dates_are_locked_once_the_gear_is_picked_up(): void
    {
        // r-4: sedang disewa Budi selama empat hari.
        $this->assertApiError($this->ask('r-4', 5, 8), 'INVALID_STATE', 409);
    }

    public function test_a_paid_rental_is_not_a_no_show_while_the_store_has_not_answered(): void
    {
        // r-3: sudah dibayar Rina, mulai besok selama dua hari.
        $this->as('rina')->postJson('/api/v1/rentals/r-3/reschedule', ['startDate' => $this->day(10), 'endDate' => $this->day(11)])->assertOk();

        $this->afterDays(3);
        $this->as('rina')->getJson('/api/v1/rentals/r-3')->assertJsonPath('data.status', 'paid');

        // Setelah ditolak, tanggal lama berlaku lagi dan sudah lewat.
        $this->as('sari')->postJson('/api/v1/rentals/r-3/reschedule-review', ['accept' => false, 'reason' => 'Penuh']);
        $this->afterDays(0);
        $this->as('rina')->getJson('/api/v1/rentals/r-3')->assertJsonPath('data.status', 'noShow');
    }
}
