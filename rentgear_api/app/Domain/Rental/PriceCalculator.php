<?php

namespace App\Domain\Rental;

/** Harga selalu dihitung di server dari data alat, tidak pernah dari kiriman aplikasi. */
final class PriceCalculator
{
    public static function subtotal(float $pricePerDay, int $qty, int $days): float
    {
        return $pricePerDay * $qty * $days;
    }

    public static function depositTotal(float $depositPerUnit, int $qty): float
    {
        return $depositPerUnit * $qty;
    }

    public static function grandTotal(float $pricePerDay, float $depositPerUnit, int $qty, int $days): float
    {
        return self::subtotal($pricePerDay, $qty, $days) + self::depositTotal($depositPerUnit, $qty);
    }
}
