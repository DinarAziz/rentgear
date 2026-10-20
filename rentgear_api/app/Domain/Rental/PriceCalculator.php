<?php

namespace App\Domain\Rental;

/** Harga selalu dihitung di server dari data alat, tidak pernah dari kiriman aplikasi. */
final class PriceCalculator
{
    public static function subtotal(float $pricePerDay, int $qty, int $days): float
    {
        return $pricePerDay * $qty * $days;
    }

    /** Potongan dibulatkan ke rupiah terdekat. */
    public static function discount(float $subtotal, int $percent): float
    {
        return round($subtotal * $percent / 100);
    }

    public static function depositTotal(float $depositPerUnit, int $qty): float
    {
        return $depositPerUnit * $qty;
    }

    /** Diskon hanya memotong biaya sewa; deposit tetap utuh karena denda dihitung dari deposit. */
    public static function grandTotal(float $pricePerDay, float $depositPerUnit, int $qty, int $days, int $discountPercent = 0): float
    {
        $subtotal = self::subtotal($pricePerDay, $qty, $days);

        return $subtotal - self::discount($subtotal, $discountPercent) + self::depositTotal($depositPerUnit, $qty);
    }
}
