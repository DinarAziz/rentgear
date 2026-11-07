<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Kode serah terima (QR) per sewa, penanda email pengingat yang sudah dikirim, dan daftar alat favorit penyewa.
 * Sewa lama langsung diberi kode supaya serah terima yang sedang berjalan tidak macet.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('rentals', function (Blueprint $table) {
            $table->string('handover_code', 6)->nullable();
            $table->timestamp('due_reminder_sent_at')->nullable();
            $table->timestamp('overdue_notice_sent_at')->nullable();
        });
        foreach (DB::table('rentals')->pluck('id') as $id) {
            DB::table('rentals')->where('id', $id)->update(['handover_code' => self::code()]);
        }

        Schema::create('wishlists', function (Blueprint $table) {
            $table->string('customer_id');
            $table->string('equipment_id');
            $table->timestamp('created_at')->nullable();
            $table->primary(['customer_id', 'equipment_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wishlists');
        Schema::table('rentals', fn (Blueprint $table) => $table->dropColumn([
            'handover_code', 'due_reminder_sent_at', 'overdue_notice_sent_at',
        ]));
    }

    private static function code(): string
    {
        return str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    }
};
