<?php

namespace Tests\Unit\Domain;

use App\Domain\Rental\DiscountPolicy;
use App\Domain\Rental\PriceCalculator;
use PHPUnit\Framework\TestCase;

/** Kasus yang sama dengan `DiscountPolicy` di rentgear_app/test/discount_test.dart. */
class DiscountPolicyTest extends TestCase
{
    public function test_no_discount_by_default(): void
    {
        $policy = DiscountPolicy::fromArray(null);
        $this->assertNull($policy->error());
        $this->assertSame(0, $policy->percentFor(10));
    }

    public function test_the_percent_follows_the_rental_length(): void
    {
        $policy = new DiscountPolicy(10, 20);
        $this->assertSame(0, $policy->percentFor(2));
        $this->assertSame(10, $policy->percentFor(3));
        $this->assertSame(10, $policy->percentFor(6));
        $this->assertSame(20, $policy->percentFor(7));
    }

    public function test_the_discount_cuts_the_rent_but_not_the_deposit(): void
    {
        // 45.000 × 1 × 3 hari = 135.000, diskon 10% = 13.500, ditambah deposit 150.000.
        $this->assertSame(271500.0, PriceCalculator::grandTotal(45000, 150000, 1, 3, 10));
        $this->assertSame(285000.0, PriceCalculator::grandTotal(45000, 150000, 1, 3));
    }

    public function test_discounts_outside_the_platform_limits_are_refused(): void
    {
        $this->assertNotNull((new DiscountPolicy(10, 55))->error());
        $this->assertNotNull((new DiscountPolicy(-5, 10))->error());
        $this->assertNotNull((new DiscountPolicy(20, 10))->error());
        $this->assertNull((new DiscountPolicy(50, 50))->error());
    }
}
