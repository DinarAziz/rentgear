<?php

namespace Tests\Unit\Domain;

use App\Domain\Availability\AvailabilityService;
use PHPUnit\Framework\TestCase;

/** Kasus yang sama dengan grup "ALG-2" di rentgear_app/test/domain_test.dart. */
class AvailabilityTest extends TestCase
{
    private function day(int $n): string
    {
        return date('Y-m-d', strtotime("2026-10-01 +$n days"));
    }

    public function test_peak_not_sum_of_overlapping_bookings(): void
    {
        // A: hari 0-1 (2 unit), B: hari 2-3 (2 unit). Tidak pernah bersamaan.
        $ranges = [[$this->day(0), $this->day(1), 2], [$this->day(2), $this->day(3), 2]];
        $this->assertSame(2, AvailabilityService::peakOccupancy($ranges, $this->day(0), $this->day(3)));
        $this->assertSame(1, AvailabilityService::available(3, $ranges, $this->day(0), $this->day(3)));
    }

    public function test_overlapping_bookings_stack(): void
    {
        $ranges = [[$this->day(0), $this->day(2), 1], [$this->day(2), $this->day(4), 2]];
        $this->assertSame(3, AvailabilityService::peakOccupancy($ranges, $this->day(0), $this->day(4)));
        $this->assertSame(0, AvailabilityService::available(3, $ranges, $this->day(2), $this->day(2)));
        $this->assertSame(1, AvailabilityService::available(3, $ranges, $this->day(3), $this->day(4)));
    }

    public function test_bookings_outside_the_window_are_ignored(): void
    {
        $ranges = [[$this->day(10), $this->day(12), 5]];
        $this->assertSame(2, AvailabilityService::available(2, $ranges, $this->day(0), $this->day(5)));
    }

    public function test_available_never_goes_below_zero(): void
    {
        $ranges = [[$this->day(0), $this->day(1), 5]];
        $this->assertSame(0, AvailabilityService::available(2, $ranges, $this->day(0), $this->day(1)));
    }

    public function test_inclusive_days_counts_both_ends(): void
    {
        $this->assertSame(1, AvailabilityService::inclusiveDays($this->day(0), $this->day(0)));
        $this->assertSame(3, AvailabilityService::inclusiveDays($this->day(0), $this->day(2)));
    }
}
