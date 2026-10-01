<?php

namespace App\Services;

use App\Domain\Fines\BlacklistPolicy;
use App\Models\BlacklistEntry;
use App\Models\Rental;
use App\Models\User;
use App\Support\ApiException;

/** Riwayat pelanggaran penyewa dan blacklist (manual oleh admin, atau otomatis). */
final class BlacklistService
{
    /** Ringkasan riwayat satu penyewa, bentuknya sama dengan `CustomerRecord` di Flutter. */
    public function recordOf(User $customer): array
    {
        $rentals = Rental::where('customer_id', $customer->id)->get();

        return [
            'user' => $customer,
            'rentalCount' => $rentals->count(),
            'lateCount' => $rentals->where('late_fee', '>', 0)->count(),
            'noShowCount' => $rentals->where('status', 'noShow')->count(),
            // Denda yang masih ditinjau admin belum dihitung sebagai pelanggaran.
            'damageCount' => $rentals->filter(fn ($r) => $r->damage_fee > 0 && $r->damage_review !== 'pending')->count(),
            'fineTotal' => (float) $rentals->sum(fn ($r) => $r->late_fee + $r->damage_fee),
            'blacklist' => BlacklistEntry::find($customer->id),
        ];
    }

    public static function violations(array $record): int
    {
        return $record['lateCount'] + $record['noShowCount'] + $record['damageCount'];
    }

    /** Dipanggil setiap kali pelanggaran penyewa bisa bertambah. */
    public function autoBlacklist(string $customerId): void
    {
        if (BlacklistEntry::whereKey($customerId)->exists()) {
            return;
        }
        $customer = User::findOrFail($customerId);
        $record = $this->recordOf($customer);
        $violations = self::violations($record);
        if (! BlacklistPolicy::shouldAutoBlacklist($violations, $customer->violation_baseline)) {
            return;
        }
        $new = $violations - $customer->violation_baseline;
        BlacklistEntry::create([
            'customer_id' => $customerId,
            'reason' => "Otomatis: $new pelanggaran (terlambat {$record['lateCount']}, "
                ."tidak diambil {$record['noShowCount']}, merusak alat {$record['damageCount']}).",
            'by' => 'Sistem',
            'at' => now(),
        ]);
    }

    public function block(User $customer, User $admin, ?string $reason): void
    {
        $text = trim((string) $reason);
        if ($text === '') {
            throw new ApiException('VALIDATION', 'Alasan blacklist wajib diisi.');
        }
        BlacklistEntry::updateOrCreate(
            ['customer_id' => $customer->id],
            ['reason' => $text, 'by' => $admin->name, 'at' => now()],
        );
    }

    /** Setelah dicabut, hitungan pelanggaran untuk blacklist otomatis mulai dari awal. */
    public function unblock(User $customer): void
    {
        BlacklistEntry::whereKey($customer->id)->delete();
        $customer->update(['violation_baseline' => self::violations($this->recordOf($customer))]);
    }
}
