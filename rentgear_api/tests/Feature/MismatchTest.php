<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

class MismatchTest extends ApiTestCase
{
    /** Booking kompor Budi yang dibawa sampai alat diserahkan hari ini. */
    private function pickedUp(string $key = 'k1'): string
    {
        $rental = $this->book(['startDate' => $this->day(0), 'endDate' => $this->day(1)], $key)->json('data');
        $id = $rental['id'];
        $this->as('sari')->postJson("/api/v1/rentals/$id/guarantees/{$rental['guarantees'][0]['id']}/review", ['accept' => true]);
        $this->postJson("/api/v1/rentals/$id/confirm");
        $this->as('budi')->post("/api/v1/rentals/$id/payment", ['proof' => $this->photo()], ['Accept' => 'application/json']);
        $this->as('sari')->postJson("/api/v1/rentals/$id/payment-review", ['accept' => true]);
        $this->postJson("/api/v1/rentals/$id/handover")->assertJsonPath('data.status', 'pickedUp');

        return $id;
    }

    private function report(string $id)
    {
        return $this->as('budi')->postJson("/api/v1/rentals/$id/mismatch", ['reason' => 'Kompor tidak menyala']);
    }

    private function decide(string $id, string $decision, ?string $note = null)
    {
        return $this->as('admin')->postJson("/api/v1/rentals/$id/mismatch-decision", ['decision' => $decision, 'note' => $note]);
    }

    public function test_a_refund_closes_the_rental_returns_the_documents_and_frees_the_stock(): void
    {
        $id = $this->pickedUp();
        $free = fn () => $this->as('budi')
            ->getJson('/api/v1/equipment/e-kompor/availability?start='.$this->day(0).'&end='.$this->day(1))->json('data.available');
        $before = $free();

        $this->report($id)->assertOk()
            ->assertJsonPath('data.mismatchStatus', 'pending')->assertJsonPath('data.mismatchReason', 'Kompor tidak menyala');
        $this->assertApiError($this->report($id), 'INVALID_STATE', 409);
        // Selama admin belum memutuskan, toko belum bisa menerima alat kembali.
        $this->assertApiError($this->as('sari')->postJson("/api/v1/rentals/$id/return"), 'MISMATCH_PENDING', 409);
        // Hanya admin yang memutuskan.
        $this->assertApiError($this->postJson("/api/v1/rentals/$id/mismatch-decision", ['decision' => 'refund']), 'FORBIDDEN', 403);
        $this->assertApiError($this->decide($id, 'gratis'), 'VALIDATION', 422);

        $done = $this->decide($id, 'refund', 'Foto serah terima menunjukkan kerusakan')->assertOk()->json('data');
        $this->assertSame(['refunded', 'refund', 'returned'], [$done['status'], $done['mismatchStatus'], $done['guarantees'][0]['status']]);
        $this->assertSame($before + 1, $free());
        $this->assertApiError($this->decide($id, 'exchange'), 'INVALID_STATE', 409);
        $this->as('admin')->getJson('/api/v1/audit')->assertJsonPath('data.0.action', 'mismatch_decided');
    }

    public function test_an_exchange_or_a_refusal_lets_the_rental_go_on(): void
    {
        foreach (['exchange' => 'Barang ditukar', 'rejected' => 'Laporan ditolak'] as $decision => $label) {
            $id = $this->pickedUp($decision);
            $this->report($id)->assertOk();
            $done = $this->decide($id, $decision)->assertOk()->json('data');

            $this->assertSame(['pickedUp', $decision], [$done['status'], $done['mismatchStatus']]);
            $this->assertStringEndsWith($label, end($done['logs'])['note']);
            $this->as('sari')->postJson("/api/v1/rentals/$id/return")->assertJsonPath('data.status', 'returned');
        }
    }

    public function test_reports_are_only_taken_on_the_day_the_gear_is_handed_over(): void
    {
        // Belum diambil.
        $this->assertApiError($this->report($this->book([], 'belum')->json('data.id')), 'INVALID_STATE', 409);
        // r-4: diambil dua hari yang lalu.
        $this->assertApiError($this->report('r-4'), 'INVALID_STATE', 409);

        $id = $this->pickedUp();
        $this->assertApiError($this->as('rina')->postJson("/api/v1/rentals/$id/mismatch", ['reason' => 'x']), 'FORBIDDEN', 403);
        $this->travel(1)->days();
        $this->assertApiError($this->report($id), 'INVALID_STATE', 409);
    }
}
