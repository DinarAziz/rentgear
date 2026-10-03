<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Aturan denda per toko, dan salinannya pada tiap sewa. Kosong berarti aturan bawaan. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('providers', fn (Blueprint $table) => $table->json('fine_policy')->nullable());
        Schema::table('rentals', fn (Blueprint $table) => $table->json('fine_policy')->nullable());
    }

    public function down(): void
    {
        Schema::table('providers', fn (Blueprint $table) => $table->dropColumn('fine_policy'));
        Schema::table('rentals', fn (Blueprint $table) => $table->dropColumn('fine_policy'));
    }
};
