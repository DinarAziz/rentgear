<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Foto kondisi alat saat diserahkan dan saat kembali. Hanya ditambah, tidak pernah diubah atau dihapus. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('condition_photos', function (Blueprint $table) {
            $table->id();
            $table->string('rental_id')->index();
            $table->string('phase'); // handover, return
            $table->string('path');
            $table->dateTime('at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('condition_photos');
    }
};
