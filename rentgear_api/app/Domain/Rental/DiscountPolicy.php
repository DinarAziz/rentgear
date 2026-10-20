<?php

namespace App\Domain\Rental;

/**
 * Diskon durasi sebuah toko. Salinan dari `DiscountPolicy` di rentgear_app/lib/domain/discount.dart.
 *
 * Penyedia yang menanggung diskon, jadi penyedia yang mengaturnya; platform hanya memasang batas atas. Diskon hanya
 * memotong biaya sewa, tidak deposit. Tiap sewa menyimpan persen diskonnya saat booking dibuat.
 */
final class DiscountPolicy
{
    /** Batas platform: diskon paling besar dari biaya sewa. */
    public const MAX_PERCENT = 50;

    public const SHORT_DAYS = 3;

    public const LONG_DAYS = 7;

    public function __construct(
        /** Diskon untuk sewa minimal SHORT_DAYS hari. */
        public readonly int $shortPercent = 0,
        /** Diskon untuk sewa minimal LONG_DAYS hari. */
        public readonly int $longPercent = 0,
    ) {}

    /** Data lama dan toko yang belum mengatur apa pun tidak memberi diskon. */
    public static function fromArray(?array $data): self
    {
        return new self((int) ($data['shortPercent'] ?? 0), (int) ($data['longPercent'] ?? 0));
    }

    public function toArray(): array
    {
        return ['shortPercent' => $this->shortPercent, 'longPercent' => $this->longPercent];
    }

    /** Pesan kesalahan, atau `null` bila diskon ini ada dalam batas platform. */
    public function error(): ?string
    {
        if (min($this->shortPercent, $this->longPercent) < 0 || max($this->shortPercent, $this->longPercent) > self::MAX_PERCENT) {
            return 'Diskon harus antara 0 dan '.self::MAX_PERCENT.' persen biaya sewa.';
        }
        if ($this->longPercent < $this->shortPercent) {
            return 'Diskon sewa '.self::LONG_DAYS.' hari tidak boleh lebih kecil dari diskon '.self::SHORT_DAYS.' hari.';
        }

        return null;
    }

    public function percentFor(int $days): int
    {
        return match (true) {
            $days >= self::LONG_DAYS => $this->longPercent,
            $days >= self::SHORT_DAYS => $this->shortPercent,
            default => 0,
        };
    }
}
