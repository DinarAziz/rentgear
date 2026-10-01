<?php

namespace App\Domain\Fines;

use App\Domain\Availability\AvailabilityService;
use DateTimeInterface;

/** Salinan dari rentgear_app/lib/domain/fines.dart. */
final class FineCalculator
{
    /** Denda keterlambatan = hari terlambat × tarif harian × jumlah unit × pengali ini. */
    public const LATE_FEE_MULTIPLIER = 1.5;

    /** Denda kerusakan di atas porsi deposit ini ditinjau admin sebelum transaksi ditutup. */
    public const DAMAGE_REVIEW_SHARE = 0.5;

    /** Hari terlambat dihitung per tanggal kalender, bukan per 24 jam. */
    public static function lateDays(string|DateTimeInterface $endDate, string|DateTimeInterface $returnedAt): int
    {
        return max(0, AvailabilityService::dayIndex($returnedAt) - AvailabilityService::dayIndex($endDate));
    }

    public static function lateFee(float $pricePerDay, int $qty, int $days): float
    {
        return $days * $pricePerDay * $qty * self::LATE_FEE_MULTIPLIER;
    }

    /** Pesan kesalahan, atau `null` bila denda kerusakan sah untuk kondisi tersebut. */
    public static function damageFeeError(ReturnCondition $condition, float $fee, float $deposit): ?string
    {
        if ($fee < 0) {
            return 'Denda kerusakan tidak boleh negatif.';
        }
        if ($condition === ReturnCondition::Good) {
            return $fee > 0 ? 'Alat berkondisi baik tidak dikenai denda kerusakan.' : null;
        }
        if ($fee <= 0) {
            return 'Isi nominal denda kerusakan.';
        }
        if ($fee > $deposit) {
            return 'Denda kerusakan tidak boleh melebihi deposit.';
        }

        return null;
    }

    public static function needsAdminReview(float $fee, float $deposit): bool
    {
        return $fee > $deposit * self::DAMAGE_REVIEW_SHARE;
    }
}
