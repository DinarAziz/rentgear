<?php

namespace Tests\Unit\Domain;

use App\Domain\Fines\FinePolicy;
use App\Domain\Fines\ReturnCondition;
use DateTimeImmutable;
use PHPUnit\Framework\TestCase;

/** Kasus yang sama dengan `FinePolicy` di rentgear_app/test/fines_test.dart. */
class FinePolicyTest extends TestCase
{
    public function test_defaults_match_the_old_fixed_rules(): void
    {
        $policy = new FinePolicy;
        $this->assertNull($policy->error());
        $this->assertSame(135000.0, $policy->lateFee(45000, 1, 2));
        $this->assertSame(1, $policy->lateDays('2026-10-05', new DateTimeImmutable('2026-10-06 00:01')));
        $this->assertEquals($policy, FinePolicy::fromArray(null));
    }

    public function test_grace_hours_and_multiplier_change_the_late_fee(): void
    {
        $policy = new FinePolicy(lateMultiplier: 2.0, graceHours: 3);
        $this->assertSame(0, $policy->lateDays('2026-10-05', new DateTimeImmutable('2026-10-06 02:59')));
        $this->assertSame(1, $policy->lateDays('2026-10-05', new DateTimeImmutable('2026-10-06 03:00')));
        $this->assertSame(3, $policy->lateDays('2026-10-05', new DateTimeImmutable('2026-10-08 10:00')));
        $this->assertSame(180000.0, $policy->lateFee(45000, 1, 2));
    }

    public function test_the_damage_guideline_is_a_share_of_the_deposit(): void
    {
        $policy = new FinePolicy(minorDamagePercent: 20, majorDamagePercent: 50, lostPercent: 100);
        $this->assertSame(0.0, $policy->guidelineFee(ReturnCondition::Good, 150000));
        $this->assertSame(30000.0, $policy->guidelineFee(ReturnCondition::MinorDamage, 150000));
        $this->assertSame(75000.0, $policy->guidelineFee(ReturnCondition::MajorDamage, 150000));
        $this->assertSame(150000.0, $policy->guidelineFee(ReturnCondition::Lost, 150000));
    }

    public function test_rules_outside_the_platform_limits_are_refused(): void
    {
        $this->assertNotNull((new FinePolicy(lateMultiplier: 2.1))->error());
        $this->assertNotNull((new FinePolicy(lateMultiplier: 0.9))->error());
        $this->assertNotNull((new FinePolicy(graceHours: 13))->error());
        $this->assertNotNull((new FinePolicy(lostPercent: 101))->error());
        $this->assertNotNull((new FinePolicy(minorDamagePercent: 70, majorDamagePercent: 60))->error());
        $this->assertNull((new FinePolicy(lateMultiplier: 1.0, graceHours: 12, minorDamagePercent: 0, majorDamagePercent: 0, lostPercent: 0))->error());
    }
}
