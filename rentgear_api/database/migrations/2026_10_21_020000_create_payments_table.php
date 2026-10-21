<?php

use App\Domain\Availability\AvailabilityService;
use App\Domain\Rental\PriceCalculator;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

/**
 * Pembayaran menjadi tabel sendiri, sesuai ERD (docs/04): satu baris per bukti transfer, jadi bukti yang ditolak tetap
 * tersimpan sebagai riwayat. Bukti lama di `rentals.payment_proof_path` dipindah ke sini, lalu kolom itu dihapus.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('rental_id')->index();
            $table->decimal('amount', 12, 2);
            $table->string('status'); // submitted, accepted, rejected
            $table->string('proof_path')->nullable();
            $table->string('note')->nullable();
            $table->dateTime('submitted_at');
            $table->dateTime('reviewed_at')->nullable();
            $table->string('reviewed_by')->nullable();
        });

        foreach (DB::table('rentals')->whereNotNull('payment_proof_path')->get() as $r) {
            $days = AvailabilityService::inclusiveDays($r->start_date, $r->end_date);
            DB::table('payments')->insert([
                'id' => strtolower((string) Str::ulid()), 'rental_id' => $r->id,
                'amount' => PriceCalculator::grandTotal((float) $r->price_per_day_snapshot, (float) $r->deposit_snapshot,
                    (int) $r->qty, $days, (int) ($r->discount_percent ?? 0)),
                'status' => match ($r->status) {
                    'paymentReview' => 'submitted',
                    'awaitingPayment' => 'rejected',
                    default => 'accepted',
                },
                'proof_path' => $r->payment_proof_path, 'submitted_at' => $r->updated_at ?? $r->created_at,
            ]);
        }
        Schema::table('rentals', fn (Blueprint $table) => $table->dropColumn('payment_proof_path'));
    }

    public function down(): void
    {
        Schema::table('rentals', fn (Blueprint $table) => $table->string('payment_proof_path')->nullable());
        foreach (DB::table('payments')->orderBy('submitted_at')->get() as $p) {
            DB::table('rentals')->where('id', $p->rental_id)->update(['payment_proof_path' => $p->proof_path]);
        }
        Schema::dropIfExists('payments');
    }
};
