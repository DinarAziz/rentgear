<?php

namespace Tests\Unit\Domain;

use App\Domain\Fines\BlacklistPolicy;
use App\Domain\Fines\FineCalculator;
use App\Domain\Fines\ReturnCondition;
use PHPUnit\Framework\TestCase;

/** Kasus yang sama dengan grup "rumus denda" di rentgear_app/test/fines_test.dart. */
class FineCalculatorTest extends TestCase
{
    public function test_late_days_follow_calendar_dates_and_never_go_negative(): void
    {
        $end = '2026-10-05';
        $this->assertSame(0, FineCalculator::lateDays($end, '2026-10-05 23:59:00'));
        $this->assertSame(1, FineCalculator::lateDays($end, '2026-10-06 00:01:00'));
        $this->assertSame(3, FineCalculator::lateDays($end, '2026-10-08'));
        $this->assertSame(0, FineCalculator::lateDays($end, '2026-10-03'));
    }

    public function test_late_fee_is_days_times_price_times_qty_times_one_and_a_half(): void
    {
        $this->assertSame(135000.0, FineCalculator::lateFee(45000, 1, 2));
        $this->assertSame(135000.0, FineCalculator::lateFee(15000, 2, 3));
        $this->assertSame(0.0, FineCalculator::lateFee(45000, 1, 0));
    }

    public function test_damage_fee_must_match_condition_and_stay_within_deposit(): void
    {
        $this->assertNull(FineCalculator::damageFeeError(ReturnCondition::Good, 0, 100000));
        $this->assertNotNull(FineCalculator::damageFeeError(ReturnCondition::Good, 10000, 100000));
        $this->assertNotNull(FineCalculator::damageFeeError(ReturnCondition::MinorDamage, 0, 100000));
        $this->assertNull(FineCalculator::damageFeeError(ReturnCondition::MinorDamage, 30000, 100000));
        $this->assertNull(FineCalculator::damageFeeError(ReturnCondition::Lost, 100000, 100000));
        $this->assertNotNull(FineCalculator::damageFeeError(ReturnCondition::Lost, 100001, 100000));
        $this->assertNotNull(FineCalculator::damageFeeError(ReturnCondition::MajorDamage, -1, 100000));
    }

    public function test_fee_above_half_the_deposit_needs_admin_review(): void
    {
        $this->assertFalse(FineCalculator::needsAdminReview(50000, 100000));
        $this->assertTrue(FineCalculator::needsAdminReview(50001, 100000));
    }

    public function test_auto_blacklist_counts_from_the_baseline(): void
    {
        $this->assertFalse(BlacklistPolicy::shouldAutoBlacklist(2, 0));
        $this->assertTrue(BlacklistPolicy::shouldAutoBlacklist(3, 0));
        // Setelah admin mencabut blacklist pada 3 pelanggaran, hitungan mulai lagi dari sana.
        $this->assertFalse(BlacklistPolicy::shouldAutoBlacklist(4, 3));
        $this->assertTrue(BlacklistPolicy::shouldAutoBlacklist(6, 3));
    }
}
