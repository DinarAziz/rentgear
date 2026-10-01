<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('providers', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('owner_id')->index();
            $table->string('business_name');
            $table->string('city');
            $table->string('address');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->string('status'); // pending, verified, rejected
            $table->string('bank_account')->nullable();
            // Aturan jaminan milik toko (docs/07 bagian 2).
            $table->json('accepted_types');
            $table->unsignedTinyInteger('base_required')->default(1);
            $table->decimal('high_value_threshold', 12, 2)->default(1000000);
            $table->unsignedTinyInteger('high_value_required')->default(2);
            $table->timestamps();
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('name');
            $table->unsignedInteger('sort')->default(0);
        });

        Schema::create('equipment', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('provider_id')->index();
            $table->string('category_id')->index();
            $table->string('name');
            $table->string('brand');
            $table->text('description');
            $table->decimal('price_per_day', 12, 2);
            $table->decimal('deposit_amount', 12, 2);
            $table->integer('weight_gram');
            // Stok alat tanpa ukuran. Alat berukuran memakai equipment_sizes.
            $table->unsignedInteger('stock')->default(0);
            $table->decimal('rating', 3, 1)->default(0);
            $table->unsignedTinyInteger('condition_score')->default(100);
            $table->unsignedInteger('capacity_person')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('equipment_sizes', function (Blueprint $table) {
            $table->id();
            $table->string('equipment_id')->index();
            $table->string('label');
            $table->unsignedInteger('stock');
            $table->unsignedInteger('sort')->default(0);
        });

        Schema::create('equipment_photos', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('equipment_id')->index();
            $table->string('path');
            $table->unsignedInteger('sort')->default(0);
        });

        Schema::create('rentals', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('invoice_code')->unique();
            $table->string('customer_id')->index();
            $table->string('customer_name');
            $table->string('provider_id')->index();
            $table->string('provider_name');
            $table->string('equipment_id')->index();
            $table->string('equipment_name');
            $table->string('category_id');
            $table->unsignedInteger('qty');
            $table->string('size')->nullable();
            $table->string('photo_path')->nullable();
            $table->date('start_date');
            $table->date('end_date');
            // Harga dikunci saat booking dibuat.
            $table->decimal('price_per_day_snapshot', 12, 2);
            $table->decimal('deposit_snapshot', 12, 2);
            $table->string('status')->index();
            $table->string('cancel_reason')->nullable();
            $table->string('payment_proof_path')->nullable();
            $table->dateTime('returned_at')->nullable();
            $table->string('return_condition')->nullable();
            $table->decimal('late_fee', 12, 2)->default(0);
            $table->decimal('damage_fee', 12, 2)->default(0);
            $table->string('damage_note')->nullable();
            $table->string('damage_review')->default('none'); // none, pending, decided
            $table->string('review_reason')->nullable();
            $table->string('review_note')->nullable();
            $table->timestamps();
        });

        Schema::create('rental_status_logs', function (Blueprint $table) {
            $table->id();
            $table->string('rental_id')->index();
            $table->string('from')->nullable();
            $table->string('to');
            $table->string('actor_name');
            $table->dateTime('at');
            $table->string('note')->nullable();
        });

        Schema::create('guarantees', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('rental_id')->index();
            $table->string('type');
            $table->string('holder_name');
            $table->text('number_enc');
            $table->string('number_masked');
            $table->string('photo_path')->nullable();
            $table->string('status');
            $table->string('note')->nullable();
            $table->dateTime('held_at')->nullable();
            $table->dateTime('returned_at')->nullable();
            $table->unique(['rental_id', 'type']);
        });

        Schema::create('reviews', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->string('provider_id')->index();
            $table->string('rental_id')->nullable()->unique();
            $table->string('customer_name');
            $table->unsignedTinyInteger('rating');
            $table->text('comment');
            $table->string('equipment_name')->nullable();
            $table->dateTime('at');
        });

        Schema::create('follows', function (Blueprint $table) {
            $table->string('customer_id');
            $table->string('provider_id');
            $table->primary(['customer_id', 'provider_id']);
        });

        Schema::create('blacklist_entries', function (Blueprint $table) {
            $table->string('customer_id')->primary();
            $table->string('reason');
            $table->string('by');
            $table->dateTime('at');
        });

        Schema::create('idempotency_keys', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->string('customer_id');
            $table->string('rental_id');
        });

        Schema::create('counters', function (Blueprint $table) {
            $table->string('name')->primary();
            $table->unsignedBigInteger('value')->default(0);
        });
    }

    public function down(): void
    {
        foreach ([
            'counters', 'idempotency_keys', 'blacklist_entries', 'follows', 'reviews', 'guarantees',
            'rental_status_logs', 'rentals', 'equipment_photos', 'equipment_sizes', 'equipment',
            'categories', 'providers',
        ] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
