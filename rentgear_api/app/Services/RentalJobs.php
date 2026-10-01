<?php

namespace App\Services;

use App\Domain\Rental\RentalStatus;
use App\Models\Rental;
use Illuminate\Support\Facades\DB;

/**
 * Perubahan status otomatis. Di aplikasi lokal ini dijalankan saat aplikasi
 * dibuka; di server dijalankan scheduler.
 */
final class RentalJobs
{
    public function __construct(
        private readonly RentalFlowService $flow,
        private readonly BlacklistService $blacklist,
    ) {}

    /** Mengembalikan jumlah transaksi yang berubah. */
    public function run(): int
    {
        $now = now();
        $today = $now->format('Y-m-d');
        $changed = 0;

        $rentals = Rental::with('guarantees', 'logs')
            ->whereIn('status', ['pendingConfirmation', 'awaitingPayment', 'paid', 'pickedUp'])->get();
        foreach ($rentals as $rental) {
            $hours = $rental->logs->last()->at->diffInHours($now);
            [$to, $note] = match (true) {
                $rental->status === 'pendingConfirmation' && $hours > 12 => [RentalStatus::Expired, 'Penyedia tidak merespons dalam 12 jam'],
                $rental->status === 'awaitingPayment' && $hours > 24 => [RentalStatus::Cancelled, 'Tidak dibayar dalam 24 jam'],
                $rental->status === 'paid' && $today > $rental->start_date->format('Y-m-d') => [RentalStatus::NoShow, 'Alat tidak diambil sampai tanggal mulai lewat'],
                $rental->status === 'pickedUp' && $today > $rental->end_date->format('Y-m-d') => [RentalStatus::Overdue, 'Melewati tanggal selesai'],
                default => [null, null],
            };
            if ($to === null) {
                continue;
            }

            DB::transaction(function () use ($rental, $to, $note) {
                $this->flow->transition($rental, $to, null, $note);
                if ($to === RentalStatus::Expired || $to === RentalStatus::Cancelled) {
                    $rental->update(['cancel_reason' => $note]);
                }
                if ($to === RentalStatus::NoShow) {
                    $this->blacklist->autoBlacklist($rental->customer_id);
                }
            });
            $changed++;
        }

        return $changed;
    }
}
