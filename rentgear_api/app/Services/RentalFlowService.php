<?php

namespace App\Services;

use App\Domain\Fines\FineCalculator;
use App\Domain\Fines\ReturnCondition;
use App\Domain\Rental\RentalStateMachine;
use App\Domain\Rental\RentalStatus;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use App\Support\ApiException;
use Closure;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Semua aksi atas transaksi yang sudah ada. Perilakunya sama dengan
 * `LocalRentGearRepository` di aplikasi Flutter.
 */
final class RentalFlowService
{
    public function __construct(private readonly BlacklistService $blacklist) {}

    /** Jalankan aksi atas satu transaksi di dalam transaksi database, dengan baris terkunci. */
    private function on(string $rentalId, Closure $action): Rental
    {
        return DB::transaction(function () use ($rentalId, $action) {
            $rental = Rental::with('guarantees')->lockForUpdate()->find($rentalId)
                ?? throw new ApiException('NOT_FOUND', 'Transaksi tidak ditemukan.');
            $action($rental);

            return $rental;
        });
    }

    private function requireOwner(Rental $r, User $actor): void
    {
        if (! $actor->isProvider() || $actor->provider_id !== $r->provider_id) {
            throw new ApiException('FORBIDDEN', 'Transaksi ini bukan milik toko Anda.');
        }
    }

    private function requireRenter(Rental $r, User $actor): void
    {
        if (! $actor->isCustomer() || $actor->id !== $r->customer_id) {
            throw new ApiException('FORBIDDEN', 'Transaksi ini bukan milik Anda.');
        }
    }

    private function requireAdmin(User $actor): void
    {
        if (! $actor->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya admin yang boleh melakukan aksi ini.');
        }
    }

    /** `$actor` null = job sistem. */
    public function transition(Rental $r, RentalStatus $to, ?User $actor, ?string $note = null): void
    {
        $from = RentalStatus::from($r->status);
        $error = RentalStateMachine::guardError($from, $to, $actor?->role, $r->guarantees->pluck('status')->all());
        if ($error !== null) {
            throw new ApiException('INVALID_TRANSITION', $error);
        }
        $r->logs()->create([
            'from' => $from->value,
            'to' => $to->value,
            'actor_name' => match (true) {
                $actor === null => 'Sistem',
                $actor->isProvider() => $r->provider_name,
                default => $actor->name,
            },
            'at' => now(),
            'note' => $note,
        ]);
        $r->update(['status' => $to->value]);
    }

    public function reviewGuarantee(string $rentalId, string $guaranteeId, User $actor, bool $accept, ?string $note): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($guaranteeId, $actor, $accept, $note) {
            $this->requireOwner($r, $actor);
            if ($r->status !== 'pendingConfirmation') {
                throw new ApiException('INVALID_STATE', 'Jaminan hanya bisa diperiksa sebelum konfirmasi.');
            }
            $guarantee = $r->guarantees->firstWhere('id', $guaranteeId)
                ?? throw new ApiException('NOT_FOUND', 'Jaminan tidak ditemukan.');
            $guarantee->update(['status' => $accept ? 'verified' : 'rejected', 'note' => $note]);
        });
    }

    public function confirm(string $rentalId, User $actor): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor) {
            $this->requireOwner($r, $actor);
            $this->transition($r, RentalStatus::AwaitingPayment, $actor);
        });
    }

    public function reject(string $rentalId, User $actor, string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $reason) {
            $this->requireOwner($r, $actor);
            $this->transition($r, RentalStatus::Rejected, $actor, $reason);
            $r->update(['cancel_reason' => $reason]);
        });
    }

    public function cancel(string $rentalId, User $actor, string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $reason) {
            $this->requireRenter($r, $actor);
            $this->transition($r, RentalStatus::Cancelled, $actor, $reason);
            $r->update(['cancel_reason' => $reason]);
        });
    }

    public function submitPayment(string $rentalId, User $actor, UploadedFile $proof): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $proof) {
            $this->requireRenter($r, $actor);
            // Sama dengan aplikasi lokal: bukti langsung dianggap sah. Pencocokan
            // nominal menunggu payment gateway.
            $this->transition($r, RentalStatus::Paid, $actor, 'Bukti bayar diunggah');
            $r->update(['payment_proof_path' => $proof->storeAs('payments', "{$r->id}.".$proof->extension(), 'local')]);
        });
    }

    public function handover(string $rentalId, User $actor): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor) {
            $this->requireOwner($r, $actor);
            if ($r->status !== 'paid') {
                throw new ApiException('INVALID_STATE', 'Alat hanya bisa diserahkan setelah pembayaran.');
            }
            $r->guarantees->each->update(['status' => 'held', 'held_at' => now()]);
            $this->transition($r, RentalStatus::PickedUp, $actor, 'Dokumen asli jaminan diterima provider');
        });
    }

    /** Denda keterlambatan memakai tanggal server, bukan tanggal dari aplikasi. */
    public function receiveReturn(string $rentalId, User $actor, ReturnCondition $condition, float $damageFee, ?string $damageNote): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $condition, $damageFee, $damageNote) {
            $this->requireOwner($r, $actor);
            $error = FineCalculator::damageFeeError($condition, $damageFee, $r->depositTotal());
            if ($error !== null) {
                throw new ApiException('VALIDATION', $error);
            }

            $now = now();
            $days = FineCalculator::lateDays($r->end_date, $now);
            $needsReview = FineCalculator::needsAdminReview($damageFee, $r->depositTotal());
            $this->transition($r, RentalStatus::Returned, $actor, implode('. ', array_filter([
                "Kondisi alat: {$condition->label()}",
                $days > 0 ? "Terlambat $days hari" : null,
            ])));
            $r->update([
                'returned_at' => $now,
                'return_condition' => $condition->value,
                'late_fee' => FineCalculator::lateFee($r->price_per_day_snapshot, $r->qty, $days),
                'damage_fee' => $damageFee,
                'damage_note' => $damageNote === null ? null : trim($damageNote),
                'damage_review' => $needsReview ? 'pending' : 'none',
                'review_reason' => $needsReview ? 'Denda kerusakan lebih dari separuh deposit.' : null,
            ]);
            $this->blacklist->autoBlacklist($r->customer_id);
        });
    }

    public function objectToDamageFee(string $rentalId, User $actor, string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $reason) {
            $this->requireRenter($r, $actor);
            if ($r->status !== 'returned' || $r->damage_fee <= 0 || $r->damage_review !== 'none') {
                throw new ApiException('INVALID_STATE', 'Denda ini tidak bisa diajukan keberatan.');
            }
            $r->update(['damage_review' => 'pending', 'review_reason' => 'Keberatan penyewa: '.trim($reason)]);
        });
    }

    public function decideDamageFee(string $rentalId, User $actor, float $amount, ?string $note): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $amount, $note) {
            $this->requireAdmin($actor);
            if ($r->damage_review !== 'pending') {
                throw new ApiException('INVALID_STATE', 'Tidak ada denda yang menunggu tinjauan.');
            }
            if ($amount < 0 || $amount > $r->depositTotal()) {
                throw new ApiException('VALIDATION', 'Nominal harus antara 0 dan jumlah deposit.');
            }
            $r->update([
                'damage_fee' => $amount,
                'damage_review' => 'decided',
                'review_note' => $note === null ? null : trim($note),
            ]);
            $this->blacklist->autoBlacklist($r->customer_id);
        });
    }

    public function complete(string $rentalId, User $actor): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor) {
            $this->requireOwner($r, $actor);
            if ($r->status !== 'returned') {
                throw new ApiException('INVALID_STATE', 'Alat belum dikembalikan.');
            }
            if ($r->damage_review === 'pending') {
                throw new ApiException('DAMAGE_REVIEW_PENDING', 'Denda kerusakan masih ditinjau admin.');
            }
            $r->guarantees->each->update(['status' => 'returned', 'returned_at' => now()]);
            $this->transition($r, RentalStatus::Completed, $actor, 'Dokumen asli jaminan dikembalikan ke penyewa');
        });
    }

    public function submitReview(string $rentalId, User $actor, int $rating, string $comment): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $rating, $comment) {
            $this->requireRenter($r, $actor);
            if ($r->status !== 'completed') {
                throw new ApiException('INVALID_STATE', 'Ulasan hanya untuk transaksi yang sudah selesai.');
            }
            if (Review::where('rental_id', $r->id)->exists()) {
                throw new ApiException('ALREADY_REVIEWED', 'Transaksi ini sudah Anda ulas.');
            }
            if ($rating < 1 || $rating > 5) {
                throw new ApiException('VALIDATION', 'Pilih 1 sampai 5 bintang.');
            }
            Review::create([
                'provider_id' => $r->provider_id, 'rental_id' => $r->id, 'customer_name' => $actor->name,
                'rating' => $rating, 'comment' => trim($comment), 'equipment_name' => $r->equipment_name, 'at' => now(),
            ]);
        });
    }
}
