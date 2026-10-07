<?php

namespace App\Services;

use App\Domain\Availability\AvailabilityService;
use App\Domain\Fines\FineCalculator;
use App\Domain\Fines\ReturnCondition;
use App\Domain\Rental\RentalStateMachine;
use App\Domain\Rental\RentalStatus;
use App\Models\ConditionPhoto;
use App\Models\Equipment;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use App\Support\ApiException;
use App\Support\Audit;
use Carbon\CarbonInterface;
use Closure;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Semua aksi atas transaksi yang sudah ada. Perilakunya sama dengan
 * `LocalRentGearRepository` di aplikasi Flutter.
 */
final class RentalFlowService
{
    /** Status sebelum alat diambil. Selama ini penyewa masih boleh meminta ganti tanggal. */
    private const BEFORE_PICKUP = ['pendingConfirmation', 'awaitingPayment', 'paymentReview', 'paid'];

    /** Keputusan admin atas laporan barang tidak sesuai. */
    public const MISMATCH_DECISIONS = ['refund', 'exchange', 'rejected'];

    public function __construct(
        private readonly BlacklistService $blacklist,
        private readonly AvailabilityQuery $availability,
    ) {}

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
        // Permintaan ganti tanggal gugur begitu alat diambil atau sewa berakhir.
        if ($r->reschedule_start !== null && ! in_array($to->value, self::BEFORE_PICKUP, true)) {
            $r->update(['reschedule_start' => null, 'reschedule_end' => null]);
        }
    }

    /** Catatan riwayat tanpa perubahan status, mis. ganti tanggal atau laporan penyewa. */
    private function note(Rental $r, User $actor, string $note): void
    {
        $r->logs()->create([
            'from' => $r->status, 'to' => $r->status,
            'actor_name' => $actor->isProvider() ? $r->provider_name : $actor->name,
            'at' => now(), 'note' => $note,
        ]);
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

    /**
     * Penyewa meminta pindah tanggal sebelum alat diambil. Lama sewa harus tetap, sehingga total tidak berubah
     * dan ganti tanggal tidak menjadi perpanjangan. Tanggal baru berlaku setelah toko menyetujui.
     */
    public function requestReschedule(string $rentalId, User $actor, string $start, string $end): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $start, $end) {
            $this->requireRenter($r, $actor);
            if (! in_array($r->status, self::BEFORE_PICKUP, true)) {
                throw new ApiException('INVALID_STATE', 'Tanggal hanya bisa diganti sebelum alat diambil.');
            }
            if ($r->reschedule_start !== null) {
                throw new ApiException('INVALID_STATE', 'Permintaan ganti tanggal sebelumnya masih menunggu jawaban toko.');
            }
            if ($end < $start) {
                throw new ApiException('INVALID_DATE', 'Tanggal selesai sebelum tanggal mulai.');
            }
            $days = AvailabilityService::inclusiveDays($r->start_date, $r->end_date);
            if (AvailabilityService::inclusiveDays($start, $end) !== $days) {
                throw new ApiException('INVALID_DATE', "Lama sewa harus tetap $days hari. Sewa tidak bisa diperpanjang.");
            }
            if ($start === $r->start_date->format('Y-m-d')) {
                throw new ApiException('INVALID_DATE', 'Tanggal baru sama dengan tanggal sekarang.');
            }
            $this->requireFreeSlot($r, $start, $end);
            $r->update(['reschedule_start' => $start, 'reschedule_end' => $end]);
            $this->note($r, $actor, 'Minta ganti tanggal menjadi '.self::range($r->reschedule_start, $r->reschedule_end));
        });
    }

    /** Toko menjawab permintaan ganti tanggal. Stok diperiksa lagi, karena bisa berubah sejak permintaan dibuat. */
    public function reviewReschedule(string $rentalId, User $actor, bool $accept, ?string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $accept, $reason) {
            $this->requireOwner($r, $actor);
            if ($r->reschedule_start === null) {
                throw new ApiException('INVALID_STATE', 'Tidak ada permintaan ganti tanggal.');
            }
            $range = self::range($r->reschedule_start, $r->reschedule_end);
            if ($accept) {
                $this->requireFreeSlot($r, $r->reschedule_start->format('Y-m-d'), $r->reschedule_end->format('Y-m-d'));
                $r->update(['start_date' => $r->reschedule_start, 'end_date' => $r->reschedule_end]);
            }
            $r->update(['reschedule_start' => null, 'reschedule_end' => null]);
            $this->note($r, $actor, $accept ? "Tanggal sewa diganti menjadi $range" : "Ganti tanggal ditolak: $reason");
        });
    }

    /** Tanggal baru harus belum lewat dan stoknya cukup, tanpa menghitung sewa ini sendiri. */
    private function requireFreeSlot(Rental $r, string $start, string $end): void
    {
        if ($start < now()->format('Y-m-d')) {
            throw new ApiException('INVALID_DATE', 'Tanggal mulai sudah lewat.');
        }
        // Baris alat dikunci seperti saat booking, sehingga dua sewa tidak berebut stok yang sama.
        $equipment = Equipment::with('sizes')->lockForUpdate()->find($r->equipment_id)
            ?? throw new ApiException('NOT_FOUND', 'Alat tidak ditemukan.');
        if ($this->availability->available($equipment, $start, $end, $r->size, $r->id) < $r->qty) {
            throw new ApiException('SLOT_UNAVAILABLE', 'Stok tidak cukup pada tanggal tersebut.');
        }
    }

    private static function range(CarbonInterface $start, CarbonInterface $end): string
    {
        return $start->format('d/m/Y').' s.d. '.$end->format('d/m/Y');
    }

    public function submitPayment(string $rentalId, User $actor, UploadedFile $proof): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $proof) {
            $this->requireRenter($r, $actor);
            $this->transition($r, RentalStatus::PaymentReview, $actor, 'Bukti transfer diunggah');
            $r->update(['payment_proof_path' => $proof->storeAs('payments', "{$r->id}.".$proof->extension(), 'local')]);
        });
    }

    /** Penyedia memeriksa bukti transfer. Bila ditolak, penyewa kembali ke "Menunggu pembayaran" dan bisa mengunggah ulang. */
    public function reviewPayment(string $rentalId, User $actor, bool $accept, ?string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $accept, $reason) {
            $this->requireOwner($r, $actor);
            if ($accept) {
                $this->transition($r, RentalStatus::Paid, $actor, 'Bukti transfer diterima');
            } else {
                $this->transition($r, RentalStatus::AwaitingPayment, $actor, "Bukti transfer ditolak: $reason");
            }
        });
    }

    /**
     * Penyedia menambah foto kondisi alat: saat diserahkan (sebelum atau sesudah serah terima, selama alat belum
     * kembali) atau saat kembali (setelah alat diterima, sebelum transaksi ditutup). Foto tidak bisa dihapus.
     */
    public function addConditionPhoto(string $rentalId, User $actor, string $phase, UploadedFile $photo): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $phase, $photo) {
            $this->requireOwner($r, $actor);
            [$allowed, $error] = $phase === ConditionPhoto::HANDOVER
                ? [['paid', 'pickedUp'], 'Foto serah terima hanya bisa ditambah sebelum alat kembali.']
                : [['returned'], 'Foto pengembalian hanya bisa ditambah setelah alat diterima dan sebelum transaksi ditutup.'];
            if (! in_array($r->status, $allowed, true)) {
                throw new ApiException('INVALID_STATE', $error);
            }
            $count = $r->conditionPhotos()->where('phase', $phase)->count();
            if ($count >= ConditionPhoto::MAX_PER_PHASE) {
                throw new ApiException('VALIDATION', 'Paling banyak '.ConditionPhoto::MAX_PER_PHASE.' foto per tahap.');
            }
            $name = $phase.'-'.($count + 1).'.'.$photo->extension();
            $r->conditionPhotos()->create([
                'phase' => $phase, 'path' => $photo->storeAs("condition/{$r->id}", $name, 'local'), 'at' => now(),
            ]);
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

    /** Penyewa melaporkan barang tidak sesuai ke admin. Hanya pada hari alat diterima, sekali per sewa. */
    public function reportMismatch(string $rentalId, User $actor, string $reason): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $reason) {
            $this->requireRenter($r, $actor);
            $handover = $r->logs->last(fn ($log) => $log->from === 'paid' && $log->to === 'pickedUp')?->at;
            if ($r->status !== 'pickedUp' || $handover === null || ! $handover->isSameDay(now())) {
                throw new ApiException('INVALID_STATE', 'Barang tidak sesuai hanya bisa dilaporkan pada hari alat diterima.');
            }
            if ($r->mismatch_status !== 'none') {
                throw new ApiException('INVALID_STATE', 'Sewa ini sudah pernah dilaporkan.');
            }
            $r->update(['mismatch_status' => 'pending', 'mismatch_reason' => trim($reason)]);
            $this->note($r, $actor, 'Melaporkan barang tidak sesuai: '.trim($reason));
        });
    }

    /**
     * Admin memutuskan laporan barang tidak sesuai. Refund menutup sewa: alat dan dokumen jaminan dikembalikan,
     * dan toko mentransfer uangnya di luar aplikasi. Tukar barang dan penolakan membiarkan sewa berjalan.
     */
    public function decideMismatch(string $rentalId, User $actor, string $decision, ?string $note): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $decision, $note) {
            $this->requireAdmin($actor);
            if ($r->mismatch_status !== 'pending') {
                throw new ApiException('INVALID_STATE', 'Tidak ada laporan yang menunggu keputusan.');
            }
            $trimmed = trim((string) $note);
            $label = match ($decision) {
                'refund' => 'Dana dikembalikan',
                'exchange' => 'Barang ditukar',
                'rejected' => 'Laporan ditolak',
            };
            $suffix = $trimmed === '' ? '' : ". Catatan: $trimmed";
            $text = "Keputusan admin atas laporan barang tidak sesuai: $label$suffix";
            if ($decision === 'refund') {
                $r->guarantees->each->update(['status' => 'returned', 'returned_at' => now()]);
                $this->transition($r, RentalStatus::Refunded, $actor, $text);
            } else {
                $this->note($r, $actor, $text);
            }
            $r->update(['mismatch_status' => $decision, 'mismatch_note' => $trimmed === '' ? null : $trimmed]);
            Audit::record($actor, Audit::MISMATCH_DECIDED, $r->invoice_code, $label.$suffix);
        });
    }

    /** Denda keterlambatan memakai tanggal server, bukan tanggal dari aplikasi. */
    public function receiveReturn(string $rentalId, User $actor, ReturnCondition $condition, float $damageFee, ?string $damageNote): Rental
    {
        return $this->on($rentalId, function (Rental $r) use ($actor, $condition, $damageFee, $damageNote) {
            $this->requireOwner($r, $actor);
            if ($r->mismatch_status === 'pending') {
                throw new ApiException('MISMATCH_PENDING', 'Laporan barang tidak sesuai masih diproses admin.');
            }
            $error = FineCalculator::damageFeeError($condition, $damageFee, $r->depositTotal());
            if ($error !== null) {
                throw new ApiException('VALIDATION', $error);
            }

            $now = now();
            $policy = $r->finePolicy();
            $days = $policy->lateDays($r->end_date, $now);
            $needsReview = FineCalculator::needsAdminReview($damageFee, $r->depositTotal());
            $this->transition($r, RentalStatus::Returned, $actor, implode('. ', array_filter([
                "Kondisi alat: {$condition->label()}",
                $days > 0 ? "Terlambat $days hari" : null,
            ])));
            $r->update([
                'returned_at' => $now,
                'return_condition' => $condition->value,
                'late_fee' => $policy->lateFee($r->price_per_day_snapshot, $r->qty, $days),
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
            $trimmed = trim((string) $note);
            Audit::record($actor, Audit::DAMAGE_FEE_DECIDED, $r->invoice_code,
                'Denda akhir Rp'.number_format($amount, 0, ',', '.').($trimmed === '' ? '' : '. Catatan: '.$trimmed));
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
