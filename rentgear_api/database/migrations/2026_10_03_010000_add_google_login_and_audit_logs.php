<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Login dengan akun Google, dan jejak audit yang hanya bisa ditambah. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Kolom `sub` dari Google. Kosong untuk akun yang hanya memakai password.
            $table->string('google_id')->nullable()->unique();
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->dateTime('at')->index();
            // Kosong untuk Sistem dan untuk percobaan masuk yang gagal.
            $table->string('actor_id')->nullable()->index();
            $table->string('actor_name');
            $table->string('actor_role');
            $table->string('action')->index();
            $table->string('target')->nullable();
            $table->text('detail')->nullable();
            $table->string('ip', 45)->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('google_id');
        });
    }
};
