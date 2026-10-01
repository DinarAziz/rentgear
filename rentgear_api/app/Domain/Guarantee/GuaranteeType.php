<?php

namespace App\Domain\Guarantee;

/** Jenis dokumen yang boleh dijadikan jaminan sewa. Nilai sama dengan nama enum di Flutter. */
enum GuaranteeType: string
{
    case Ktp = 'ktp';
    case Sim = 'sim';
    case Ktm = 'ktm';
    case KartuKeluarga = 'kartuKeluarga';
    case Ijazah = 'ijazah';
    case Paspor = 'paspor';
    case Npwp = 'npwp';
    case Bpkb = 'bpkb';

    public function label(): string
    {
        return match ($this) {
            self::Ktp => 'KTP',
            self::Sim => 'SIM',
            self::Ktm => 'KTM',
            self::KartuKeluarga => 'KK',
            self::Ijazah => 'Ijazah',
            self::Paspor => 'Paspor',
            self::Npwp => 'NPWP',
            self::Bpkb => 'BPKB',
        };
    }

    /** Jumlah digit wajib bila nomornya berformat tetap (NIK dan No. KK = 16 digit). */
    public function exactDigits(): ?int
    {
        return match ($this) {
            self::Ktp, self::KartuKeluarga => 16,
            default => null,
        };
    }
}
