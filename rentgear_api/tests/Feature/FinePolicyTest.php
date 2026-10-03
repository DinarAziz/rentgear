<?php

namespace Tests\Feature;

use App\Models\Rental;
use Tests\ApiTestCase;

class FinePolicyTest extends ApiTestCase
{
    private const POLICY = ['lateMultiplier' => 2, 'graceHours' => 3, 'minorDamagePercent' => 20, 'majorDamagePercent' => 50, 'lostPercent' => 90];

    public function test_a_store_sets_its_fine_rules_within_the_platform_limits(): void
    {
        $this->as('budi')->getJson('/api/v1/providers/p-arjuna')->assertJsonPath('data.finePolicy.lateMultiplier', 1.5);
        $this->assertApiError($this->putJson('/api/v1/provider/fine-policy', self::POLICY), 'FORBIDDEN', 403);

        $this->as('sari')->putJson('/api/v1/provider/fine-policy', self::POLICY)->assertOk()
            ->assertJsonPath('data.finePolicy.lateMultiplier', 2)->assertJsonPath('data.finePolicy.graceHours', 3)
            ->assertJsonPath('data.finePolicy.lostPercent', 90);
        // Toko lain tidak ikut berubah.
        $this->getJson('/api/v1/providers/p-semeru')->assertJsonPath('data.finePolicy.lateMultiplier', 1.5);

        $response = $this->putJson('/api/v1/provider/fine-policy', [...self::POLICY, 'lateMultiplier' => 2.5]);
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertStringContainsString('antara 1 dan 2', $response->json('error.message'));
        $this->assertApiError($this->putJson('/api/v1/provider/fine-policy', [...self::POLICY, 'graceHours' => 24]), 'VALIDATION', 422);
        $this->assertApiError($this->putJson('/api/v1/provider/fine-policy', [...self::POLICY, 'minorDamagePercent' => 80]), 'VALIDATION', 422);
    }

    public function test_a_rental_keeps_the_rules_it_was_booked_under(): void
    {
        // Booking kompor di Arjuna Outdoor dengan aturan bawaan, lalu toko mengubah aturannya.
        $id = $this->book()->assertOk()->json('data.id');
        $this->as('sari')->putJson('/api/v1/provider/fine-policy', self::POLICY)->assertOk();
        $this->getJson("/api/v1/rentals/$id")->assertJsonPath('data.finePolicy.lateMultiplier', 1.5);

        // Booking berikutnya memakai aturan baru.
        $next = $this->book(['startDate' => $this->day(5), 'endDate' => $this->day(6)], 'k2')->assertOk()->json('data');
        $this->assertEquals(2, $next['finePolicy']['lateMultiplier']);
        $this->assertSame(3, $next['finePolicy']['graceHours']);
    }

    public function test_late_fees_follow_the_rules_locked_at_booking(): void
    {
        // r-4: tenda ultralight Rp60.000 per hari di Semeru Camp Rent, sedang disewa.
        $rental = Rental::findOrFail('r-4');
        $rental->update(['fine_policy' => [...self::POLICY, 'lateMultiplier' => 2, 'graceHours' => 0]]);
        $this->travelTo($rental->end_date->copy()->addDays(2)->setTime(10, 0));

        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', ['condition' => 'good'])->assertOk()
            ->assertJsonPath('data.lateFee', 240000);
    }

    public function test_the_grace_period_spares_a_return_just_after_midnight(): void
    {
        $rental = Rental::findOrFail('r-4');
        $rental->update(['fine_policy' => self::POLICY]);
        $this->travelTo($rental->end_date->copy()->addDay()->setTime(2, 30));

        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', ['condition' => 'good'])->assertOk()
            ->assertJsonPath('data.lateFee', 0);
    }
}
