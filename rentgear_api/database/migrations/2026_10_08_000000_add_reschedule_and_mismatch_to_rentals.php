<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Permintaan ganti tanggal yang menunggu jawaban toko, dan laporan barang tidak sesuai yang diputuskan admin. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            $table->date('reschedule_start')->nullable();
            $table->date('reschedule_end')->nullable();
            $table->string('mismatch_status')->default('none'); // none, pending, refund, exchange, rejected
            $table->string('mismatch_reason')->nullable();
            $table->string('mismatch_note')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('rentals', fn (Blueprint $table) => $table->dropColumn([
            'reschedule_start', 'reschedule_end', 'mismatch_status', 'mismatch_reason', 'mismatch_note',
        ]));
    }
};
