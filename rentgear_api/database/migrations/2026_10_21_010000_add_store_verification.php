<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Dokumen verifikasi toko: NIK pemilik (terenkripsi, ditambah hash untuk mencari NIK yang dipakai dua toko), foto KTP,
 * swafoto dengan KTP, dan foto toko. Admin memeriksanya sebelum toko tampil di katalog.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('providers', function (Blueprint $table) {
            $table->text('owner_nik_enc')->nullable();
            $table->string('owner_nik_masked')->nullable();
            $table->string('owner_nik_hash', 64)->nullable()->index();
            $table->string('ktp_photo_path')->nullable();
            $table->string('selfie_photo_path')->nullable();
            $table->json('store_photo_paths')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('rejection_reason')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('providers', fn (Blueprint $table) => $table->dropColumn([
            'owner_nik_enc', 'owner_nik_masked', 'owner_nik_hash', 'ktp_photo_path', 'selfie_photo_path',
            'store_photo_paths', 'submitted_at', 'reviewed_at', 'rejection_reason',
        ]));
    }
};
