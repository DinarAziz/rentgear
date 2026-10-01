<?php

namespace Tests\Feature;

use App\Models\Guarantee;
use App\Models\Rental;
use Illuminate\Support\Facades\Storage;
use Tests\ApiTestCase;

/** Kasus yang sama dengan rentgear_app/test/rental_flow_test.dart. */
class BookingTest extends ApiTestCase
{
    public function test_booking_locks_the_price_and_stores_the_document_privately(): void
    {
        $data = $this->book(['qty' => 2])->assertOk()->json('data');

        $this->assertSame('pendingConfirmation', $data['status']);
        $this->assertSame('Arjuna Outdoor', $data['providerName']);
        $this->assertEquals(20000, $data['pricePerDaySnapshot']);
        $this->assertEquals(50000, $data['depositSnapshot']);
        $this->assertMatchesRegularExpression('/^INV-\d{8}-\d{4}$/', $data['invoiceCode']);
        $this->assertSame('submitted', $data['guarantees'][0]['status']);
        $this->assertSame('••••••••••••0001', $data['guarantees'][0]['maskedNumber']);
        $this->assertArrayNotHasKey('documentNumber', $data['guarantees'][0]);
        $this->assertSame([null], array_column($data['logs'], 'from'));

        $guarantee = Guarantee::find($data['guarantees'][0]['id']);
        Storage::disk('local')->assertExists($guarantee->photo_path);
        $this->assertSame('3573011204020001', $guarantee->number_enc);
    }

    public function test_the_client_cannot_set_the_price(): void
    {
        $data = $this->book(['pricePerDaySnapshot' => 1, 'depositSnapshot' => 1])->json('data');
        $this->assertEquals(20000, $data['pricePerDaySnapshot']);
    }

    public function test_booking_without_guarantee_is_refused(): void
    {
        $this->assertApiError($this->book(['guarantees' => []]), 'GUARANTEE_INVALID', 422);
        $this->assertSame(6, Rental::count());
    }

    public function test_high_value_booking_needs_two_guarantees(): void
    {
        // 4 kompor × 10 hari × 20rb + deposit 4 × 50rb = 1.000.000 → wajib 2.
        $response = $this->book(['qty' => 4, 'startDate' => $this->day(20), 'endDate' => $this->day(29)]);
        $this->assertApiError($response, 'GUARANTEE_INVALID', 422);
        $this->assertStringContainsString('minimal 2', $response->json('error.message'));
    }

    public function test_same_idempotency_key_returns_the_same_booking(): void
    {
        $first = $this->book()->json('data.id');
        $second = $this->book()->assertOk()->json('data.id');

        $this->assertSame($first, $second);
        $this->assertSame(7, Rental::count());
    }

    public function test_idempotency_key_header_is_required(): void
    {
        $response = $this->as('budi')->postJson('/api/v1/rentals', [
            'equipmentId' => 'e-kompor', 'qty' => 1, 'startDate' => $this->day(1), 'endDate' => $this->day(2),
        ]);
        $this->assertApiError($response, 'VALIDATION', 422);
    }

    public function test_double_booking_is_blocked_by_alg_2(): void
    {
        // Tenda Dome stok 3; seed sudah memakai 1 (hari +3..+5) dan 2 (hari +4..+6).
        $response = $this->book(['equipmentId' => 'e-dome4', 'startDate' => $this->day(4), 'endDate' => $this->day(4)]);
        $this->assertApiError($response, 'SLOT_UNAVAILABLE', 409);
    }

    public function test_last_unit_goes_to_exactly_one_of_two_bookings(): void
    {
        // Tenda ultralight stok 2, r-4 memakai 1 sampai besok: tersisa 1 unit untuk besok.
        $range = ['equipmentId' => 'e-ul2p', 'startDate' => $this->day(1), 'endDate' => $this->day(1)];
        $this->book($range, 'a')->assertOk();
        $this->assertApiError($this->book($range, 'b'), 'SLOT_UNAVAILABLE', 409);
    }

    public function test_dates_and_quantity_are_checked(): void
    {
        $this->assertApiError($this->book(['startDate' => $this->day(-1)]), 'INVALID_DATE', 422);
        $this->assertApiError($this->book(['startDate' => $this->day(3), 'endDate' => $this->day(2)]), 'INVALID_DATE', 422);
        $this->assertApiError($this->book(['qty' => 0]), 'INVALID_QTY', 422);
        $this->assertApiError($this->book(['equipmentId' => 'e-tidak-ada']), 'NOT_FOUND', 404);
        $this->assertApiError($this->book(['equipmentId' => 'e-family6']), 'PROVIDER_INACTIVE', 422);
    }

    public function test_size_is_required_and_must_exist(): void
    {
        $shoe = ['equipmentId' => 'e-sepatu', 'startDate' => $this->day(2), 'endDate' => $this->day(3)];
        $this->assertApiError($this->book($shoe), 'SIZE_REQUIRED', 422);
        $this->assertApiError($this->book([...$shoe, 'size' => '50']), 'SIZE_REQUIRED', 422);
        $this->assertApiError($this->book(['size' => '42']), 'VALIDATION', 422); // kompor tidak punya ukuran
    }

    public function test_stock_is_tracked_per_size(): void
    {
        $shoe = ['equipmentId' => 'e-sepatu', 'startDate' => $this->day(2), 'endDate' => $this->day(3), 'size' => '43'];
        $this->book($shoe, 's1')->assertOk()->assertJsonPath('data.size', '43');

        $availability = $this->getJson("/api/v1/equipment/e-sepatu/availability?start={$this->day(2)}&end={$this->day(3)}")->json('data');
        $this->assertSame(0, $availability['sizes']['43']); // ukuran 43 habis
        $this->assertSame(2, $availability['sizes']['42']); // ukuran lain tidak terpengaruh
        $this->assertSame(8, $availability['available']);

        $this->assertApiError($this->book($shoe, 's2'), 'SLOT_UNAVAILABLE', 409);
    }

    public function test_only_customers_can_book(): void
    {
        $response = $this->as('sari')->postJson('/api/v1/rentals', [
            'equipmentId' => 'e-kompor', 'qty' => 1, 'startDate' => $this->day(1), 'endDate' => $this->day(2),
        ], ['Idempotency-Key' => 'p1']);
        $this->assertApiError($response, 'FORBIDDEN', 403);
    }
}
