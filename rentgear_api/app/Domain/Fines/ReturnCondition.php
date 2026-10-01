<?php

namespace App\Domain\Fines;

/** Kondisi alat saat diterima kembali oleh penyedia. */
enum ReturnCondition: string
{
    case Good = 'good';
    case MinorDamage = 'minorDamage';
    case MajorDamage = 'majorDamage';
    case Lost = 'lost';

    public function label(): string
    {
        return match ($this) {
            self::Good => 'Baik',
            self::MinorDamage => 'Rusak ringan',
            self::MajorDamage => 'Rusak berat',
            self::Lost => 'Hilang',
        };
    }
}
