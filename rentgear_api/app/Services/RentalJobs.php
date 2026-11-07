<?php

namespace App\Services;

use App\Domain\Rental\RentalStatus;
use App\Mail\ReturnReminder;
use App\Models\Rental;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Throwable;

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
            // Catatan ganti tanggal tidak mengubah status, jadi tidak mengulang hitungan waktu.
            $hours = $rental->logs->last(fn ($log) => $log->from !== $log->to)->at->diffInHours($now);
            [$to, $note] = match (true) {
                $rental->status === 'pendingConfirmation' && $hours > 12 => [RentalStatus::Expired, 'Penyedia tidak merespons dalam 12 jam'],
                $rental->status === 'awaitingPayment' && $hours > 24 => [RentalStatus::Cancelled, 'Tidak dibayar dalam 24 jam'],
                // Selama toko belum menjawab permintaan ganti tanggal, penyewa belum dianggap tidak datang.
                $rental->status === 'paid' && $rental->reschedule_start === null && $today > $rental->start_date->format('Y-m-d') => [RentalStatus::NoShow, 'Alat tidak diambil sampai tanggal mulai lewat'],
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
        $this->sendReminders();

        return $changed;
    }

    /** Email H-1 sebelum tanggal kembali dan email saat terlambat. Masing-masing sekali per sewa. */
    private function sendReminders(): void
    {
        $tomorrow = now()->addDay()->format('Y-m-d');
        $due = Rental::where('status', 'pickedUp')->whereNull('due_reminder_sent_at')
            ->whereDate('end_date', '<=', $tomorrow)->get();
        $late = Rental::where('status', 'overdue')->whereNull('overdue_notice_sent_at')->get();

        foreach ([[$due, false, 'due_reminder_sent_at'], [$late, true, 'overdue_notice_sent_at']] as [$rentals, $overdue, $column]) {
            foreach ($rentals as $r) {
                // Ditandai terkirim walau gagal, supaya scheduler tidak mencoba ulang tiap 10 menit.
                $r->update([$column => now()]);
                $customer = User::find($r->customer_id);
                if ($customer?->email === null) {
                    continue;
                }
                try {
                    Mail::to($customer->email)->send(new ReturnReminder(
                        $customer->name, $r->invoice_code, $r->equipment_name, $r->provider_name,
                        $r->end_date->locale('id')->translatedFormat('j F Y'), $overdue,
                        $r->finePolicy()->lateFee($r->price_per_day_snapshot, $r->qty, 1),
                    ));
                } catch (Throwable $e) {
                    logger()->warning("Email pengingat {$r->invoice_code} gagal: ".$e->getMessage());
                }
            }
        }
    }
}
