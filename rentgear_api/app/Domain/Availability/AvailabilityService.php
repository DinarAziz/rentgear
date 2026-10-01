<?php

namespace App\Domain\Availability;

use DateTimeInterface;

/**
 * ALG-2 Availability Sweep-Line.
 *
 * Stok tersedia = stok total - okupansi PUNCAK pada rentang yang diminta,
 * bukan stok total - jumlah semua booking yang beririsan.
 * Salinan dari rentgear_app/lib/domain/availability.dart.
 */
final class AvailabilityService
{
    /** Nomor hari sejak epoch, supaya selisih hari tidak terganggu jam. */
    public static function dayIndex(string|DateTimeInterface $date): int
    {
        $day = $date instanceof DateTimeInterface ? $date->format('Y-m-d') : substr($date, 0, 10);

        return intdiv(strtotime($day.' 00:00:00 UTC'), 86400);
    }

    /** Jumlah hari sewa, inklusif tanggal mulai dan selesai. */
    public static function inclusiveDays(string|DateTimeInterface $start, string|DateTimeInterface $end): int
    {
        return self::dayIndex($end) - self::dayIndex($start) + 1;
    }

    /**
     * Tiap rentang: [mulai, selesai, jumlah unit], kedua tanggal inklusif.
     *
     * @param  array<int, array{0: string|DateTimeInterface, 1: string|DateTimeInterface, 2: int}>  $ranges
     */
    public static function peakOccupancy(array $ranges, string|DateTimeInterface $start, string|DateTimeInterface $end): int
    {
        $from = self::dayIndex($start);
        $to = self::dayIndex($end);
        $events = [];

        foreach ($ranges as [$rangeStart, $rangeEnd, $qty]) {
            $s = max(self::dayIndex($rangeStart), $from);
            $e = min(self::dayIndex($rangeEnd), $to);
            if ($s > $e) {
                continue; // tidak beririsan
            }
            $events[$s] = ($events[$s] ?? 0) + $qty;
            $events[$e + 1] = ($events[$e + 1] ?? 0) - $qty;
        }

        ksort($events);
        $running = 0;
        $peak = 0;
        foreach ($events as $delta) {
            $running += $delta;
            $peak = max($peak, $running);
        }

        return $peak;
    }

    public static function available(int $stock, array $ranges, string|DateTimeInterface $start, string|DateTimeInterface $end): int
    {
        return max(0, $stock - self::peakOccupancy($ranges, $start, $end));
    }
}
