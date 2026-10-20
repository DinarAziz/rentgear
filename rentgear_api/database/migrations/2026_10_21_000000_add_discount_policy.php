<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Diskon durasi per toko, dan persen diskon yang dikunci pada tiap sewa. Kosong berarti tanpa diskon. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('providers', fn (Blueprint $table) => $table->json('discount_policy')->nullable());
        Schema::table('rentals', fn (Blueprint $table) => $table->unsignedTinyInteger('discount_percent')->default(0));
    }

    public function down(): void
    {
        Schema::table('providers', fn (Blueprint $table) => $table->dropColumn('discount_policy'));
        Schema::table('rentals', fn (Blueprint $table) => $table->dropColumn('discount_percent'));
    }
};
