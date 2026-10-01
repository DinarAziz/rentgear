<?php

namespace App\Domain\Fines;

final class BlacklistPolicy
{
    /** Jumlah pelanggaran baru yang membuat penyewa masuk blacklist otomatis. */
    public const AUTO_BLACKLIST_AFTER = 3;

    /**
     * `$baseline` = jumlah pelanggaran saat admin terakhir mencabut blacklist, supaya
     * penyewa tidak langsung masuk blacklist lagi karena pelanggaran lama.
     */
    public static function shouldAutoBlacklist(int $violations, int $baseline): bool
    {
        return $violations - $baseline >= self::AUTO_BLACKLIST_AFTER;
    }
}
