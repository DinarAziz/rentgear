<?php

namespace App\Domain\Fines;

use App\Domain\Availability\AvailabilityService;
use DateTimeInterface;

/**
 * Aturan denda sebuah toko. Salinan dari `FinePolicy` di rentgear_app/lib/domain/fines.dart.
 *
 * Penyedia mengaturnya dalam batas platform. Tiap sewa menyimpan salinannya saat booking dibuat, jadi perubahan
 * aturan tidak mengenai sewa yang sudah dipesan.
 */
final class FinePolicy
{
    public const MIN_LATE_MULTIPLIER = 1.0;

    public const MAX_LATE_MULTIPLIER = 2.0;

    public const MAX_GRACE_HOURS = 12;

    public function __construct(
        /** Denda terlambat = hari terlambat × tarif harian × jumlah unit × pengali ini. */
        public readonly float $lateMultiplier = FineCalculator::LATE_FEE_MULTIPLIER,
        /** Terlambat sampai sekian jam setelah hari terakhir sewa belum dikenai denda. */
        public readonly int $graceHours = 0,
        /** Pedoman denda kerusakan, dalam persen dari deposit. Bukan batas: penyedia tetap mengisi nominalnya. */
        public readonly int $minorDamagePercent = 25,
        public readonly int $majorDamagePercent = 60,
        public readonly int $lostPercent = 100,
    ) {}

    /** Data lama dan toko yang belum mengatur apa pun memakai nilai bawaan. */
    public static function fromArray(?array $data): self
    {
        $default = new self;

        return new self(
            (float) ($data['lateMultiplier'] ?? $default->lateMultiplier),
            (int) ($data['graceHours'] ?? $default->graceHours),
            (int) ($data['minorDamagePercent'] ?? $default->minorDamagePercent),
            (int) ($data['majorDamagePercent'] ?? $default->majorDamagePercent),
            (int) ($data['lostPercent'] ?? $default->lostPercent),
        );
    }

    public function toArray(): array
    {
        return [
            'lateMultiplier' => $this->lateMultiplier, 'graceHours' => $this->graceHours,
            'minorDamagePercent' => $this->minorDamagePercent, 'majorDamagePercent' => $this->majorDamagePercent,
            'lostPercent' => $this->lostPercent,
        ];
    }

    /** Pesan kesalahan, atau `null` bila aturan ini ada dalam batas platform. */
    public function error(): ?string
    {
        if ($this->lateMultiplier < self::MIN_LATE_MULTIPLIER || $this->lateMultiplier > self::MAX_LATE_MULTIPLIER) {
            return 'Pengali denda terlambat harus antara 1 dan 2 kali tarif harian.';
        }
        if ($this->graceHours < 0 || $this->graceHours > self::MAX_GRACE_HOURS) {
            return 'Masa tenggang paling lama '.self::MAX_GRACE_HOURS.' jam.';
        }
        $percents = [$this->minorDamagePercent, $this->majorDamagePercent, $this->lostPercent];
        if (min($percents) < 0 || max($percents) > 100) {
            return 'Pedoman denda kerusakan harus antara 0 dan 100 persen deposit.';
        }
        if ($this->minorDamagePercent > $this->majorDamagePercent || $this->majorDamagePercent > $this->lostPercent) {
            return 'Pedoman denda harus naik: rusak ringan, rusak berat, lalu hilang.';
        }

        return null;
    }

    /** Hari terlambat per tanggal kalender, setelah dikurangi masa tenggang. */
    public function lateDays(string|DateTimeInterface $endDate, DateTimeInterface $returnedAt): int
    {
        $counted = \DateTimeImmutable::createFromInterface($returnedAt)->modify("-{$this->graceHours} hours");

        return max(0, AvailabilityService::dayIndex($counted) - AvailabilityService::dayIndex($endDate));
    }

    public function lateFee(float $pricePerDay, int $qty, int $days): float
    {
        return $days * $pricePerDay * $qty * $this->lateMultiplier;
    }

    /** Nominal pedoman untuk sebuah kondisi. Alat berkondisi baik tidak dikenai denda. */
    public function guidelineFee(ReturnCondition $condition, float $deposit): float
    {
        $percent = match ($condition) {
            ReturnCondition::Good => 0,
            ReturnCondition::MinorDamage => $this->minorDamagePercent,
            ReturnCondition::MajorDamage => $this->majorDamagePercent,
            ReturnCondition::Lost => $this->lostPercent,
        };

        return round($deposit * $percent / 100);
    }
}
