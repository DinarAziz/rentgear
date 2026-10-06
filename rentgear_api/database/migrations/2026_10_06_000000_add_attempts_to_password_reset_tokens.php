<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Lupa password: jumlah tebakan atas satu kode, supaya kode 6 angka tidak bisa dicoba terus-menerus. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('password_reset_tokens', fn (Blueprint $table) => $table->unsignedTinyInteger('attempts')->default(0));
    }

    public function down(): void
    {
        Schema::table('password_reset_tokens', fn (Blueprint $table) => $table->dropColumn('attempts'));
    }
};
