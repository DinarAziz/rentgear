<?php

namespace App\Domain\Guarantee;

/**
 * Aturan jaminan milik satu toko.
 * Salinan dari GuaranteePolicy di rentgear_app/lib/domain/guarantee.dart.
 */
final class GuaranteePolicy
{
    public const MAX_PER_BOOKING = 3;

    /** @param array<int, string> $acceptedTypes nilai GuaranteeType */
    public function __construct(
        public readonly array $acceptedTypes,
        public readonly int $baseRequired = 1,
        public readonly float $highValueThreshold = 1000000,
        public readonly int $highValueRequired = 2,
    ) {}

    public function requiredCount(float $rentalValue): int
    {
        return $rentalValue >= $this->highValueThreshold
            ? max($this->baseRequired, $this->highValueRequired)
            : $this->baseRequired;
    }

    /**
     * Daftar pesan kesalahan. Daftar kosong berarti valid.
     *
     * @param  array<int, array{type: ?string, holderName: string, documentNumber: string, hasPhoto: bool}>  $drafts
     * @return array<int, string>
     */
    public function validate(array $drafts, float $rentalValue, string $renterName): array
    {
        $errors = [];
        $required = $this->requiredCount($rentalValue);
        if (count($drafts) < $required) {
            $errors[] = "Sewa ini membutuhkan minimal $required jaminan.";
        }
        if (count($drafts) > self::MAX_PER_BOOKING) {
            $errors[] = 'Maksimal '.self::MAX_PER_BOOKING.' jaminan per sewa.';
        }

        $seen = [];
        foreach (array_values($drafts) as $i => $draft) {
            $n = 'Jaminan '.($i + 1);
            $type = GuaranteeType::tryFrom((string) ($draft['type'] ?? ''));
            if ($type === null) {
                $errors[] = "$n: pilih jenis dokumen.";

                continue;
            }
            if (! in_array($type->value, $this->acceptedTypes, true)) {
                $errors[] = "$n: {$type->label()} tidak diterima provider ini.";
            }
            if (in_array($type, $seen, true)) {
                $errors[] = "$n: {$type->label()} sudah dipakai. Gunakan jenis lain.";
            }
            $seen[] = $type;

            $number = preg_replace('/\s/u', '', (string) ($draft['documentNumber'] ?? ''));
            $digits = $type->exactDigits();
            if ($number === '') {
                $errors[] = "$n: nomor dokumen wajib diisi.";
            } elseif ($digits !== null && ! preg_match('/^\d{'.$digits.'}$/', $number)) {
                $errors[] = "$n: nomor {$type->label()} harus $digits digit angka.";
            }
            if (self::normalize((string) ($draft['holderName'] ?? '')) !== self::normalize($renterName)) {
                $errors[] = "$n: dokumen harus atas nama penyewa ($renterName).";
            }
            if (empty($draft['hasPhoto'])) {
                $errors[] = "$n: foto dokumen wajib diunggah.";
            }
        }

        return $errors;
    }

    /** Semua karakter kecuali 4 terakhir diganti titik. */
    public static function mask(string $number): string
    {
        $clean = preg_replace('/\s/u', '', $number);
        $length = mb_strlen($clean);
        if ($length <= 4) {
            return '••••';
        }

        return str_repeat('•', $length - 4).mb_substr($clean, -4);
    }

    private static function normalize(string $value): string
    {
        return preg_replace('/\s+/u', ' ', mb_strtolower(trim($value)));
    }
}
