<?php

namespace App\Services;

use App\Domain\Availability\AvailabilityService;
use App\Domain\Guarantee\GuaranteePolicy;
use App\Domain\Rental\PriceCalculator;
use App\Models\BlacklistEntry;
use App\Models\Equipment;
use App\Models\Guarantee;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\User;
use App\Support\ApiException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Membuat booking: urutan pemeriksaannya sama dengan `createBooking` di repository Flutter. */
final class BookingService
{
    public function __construct(private readonly AvailabilityQuery $availability) {}

    /**
     * @param  array{equipmentId: string, qty: int, size: ?string, startDate: string, endDate: string}  $data
     * @param  array<int, array{type: ?string, holderName: ?string, documentNumber: ?string, photo: ?UploadedFile}>  $guarantees
     */
    public function create(User $customer, array $data, array $guarantees, string $idempotencyKey): Rental
    {
        return DB::transaction(function () use ($customer, $data, $guarantees, $idempotencyKey) {
            // Kirim ulang dengan key yang sama tidak membuat booking ganda.
            $existing = DB::table('idempotency_keys')
                ->where(['key' => $idempotencyKey, 'customer_id' => $customer->id])->value('rental_id');
            if ($existing !== null) {
                return Rental::findOrFail($existing);
            }

            if (! $customer->isCustomer()) {
                throw new ApiException('FORBIDDEN', 'Hanya penyewa yang bisa membuat booking.');
            }
            $blocked = BlacklistEntry::find($customer->id);
            if ($blocked !== null) {
                throw new ApiException('BLACKLISTED',
                    "Akun Anda masuk blacklist dan tidak bisa membuat booking. Alasan: {$blocked->reason}");
            }

            // Baris alat dikunci sampai transaksi selesai, sehingga dua booking untuk
            // stok terakhir tidak bisa sama-sama lolos pemeriksaan ketersediaan.
            $equipment = Equipment::with('sizes', 'photos')->lockForUpdate()->find($data['equipmentId'])
                ?? throw new ApiException('NOT_FOUND', 'Alat tidak ditemukan.');
            $provider = Provider::findOrFail($equipment->provider_id);
            if ($provider->status !== Provider::VERIFIED) {
                throw new ApiException('PROVIDER_INACTIVE', 'Penyedia belum terverifikasi.');
            }

            $start = $data['startDate'];
            $end = $data['endDate'];
            $size = $data['size'] ?? null;
            $qty = (int) $data['qty'];
            if ($start < now()->format('Y-m-d')) {
                throw new ApiException('INVALID_DATE', 'Tanggal mulai sudah lewat.');
            }
            if ($end < $start) {
                throw new ApiException('INVALID_DATE', 'Tanggal selesai sebelum tanggal mulai.');
            }
            if ($qty < 1) {
                throw new ApiException('INVALID_QTY', 'Jumlah minimal 1.');
            }
            if ($equipment->hasSizes() && ! $equipment->sizes->contains('label', $size)) {
                throw new ApiException('SIZE_REQUIRED', 'Pilih ukuran terlebih dahulu.');
            }
            if (! $equipment->hasSizes() && $size !== null) {
                throw new ApiException('VALIDATION', 'Alat ini tidak memiliki pilihan ukuran.');
            }
            if (! $equipment->is_active) {
                throw new ApiException('NOT_FOUND', 'Alat sedang tidak disewakan.');
            }
            if ($this->availability->available($equipment, $start, $end, $size) < $qty) {
                throw new ApiException('SLOT_UNAVAILABLE', 'Stok tidak cukup pada tanggal tersebut.');
            }

            $days = AvailabilityService::inclusiveDays($start, $end);
            $total = PriceCalculator::grandTotal($equipment->price_per_day, $equipment->deposit_amount, $qty, $days);
            $policy = new GuaranteePolicy($provider->accepted_types, $provider->base_required,
                $provider->high_value_threshold, $provider->high_value_required);
            $errors = $policy->validate(array_map(fn ($g) => [
                'type' => $g['type'] ?? null,
                'holderName' => (string) ($g['holderName'] ?? ''),
                'documentNumber' => (string) ($g['documentNumber'] ?? ''),
                'hasPhoto' => ($g['photo'] ?? null) instanceof UploadedFile,
            ], $guarantees), $total, $customer->name);
            if ($errors !== []) {
                throw new ApiException('GUARANTEE_INVALID', implode("\n", $errors));
            }

            $rental = Rental::create([
                'invoice_code' => $this->nextInvoiceCode(),
                'customer_id' => $customer->id, 'customer_name' => $customer->name,
                'provider_id' => $provider->id, 'provider_name' => $provider->business_name,
                'equipment_id' => $equipment->id, 'equipment_name' => $equipment->name,
                'category_id' => $equipment->category_id, 'qty' => $qty, 'size' => $size,
                'photo_path' => $equipment->photos->first()?->path,
                'start_date' => $start, 'end_date' => $end,
                'price_per_day_snapshot' => $equipment->price_per_day,
                'deposit_snapshot' => $equipment->deposit_amount,
                'status' => 'pendingConfirmation',
            ]);
            foreach ($guarantees as $g) {
                $number = preg_replace('/\s/u', '', $g['documentNumber']);
                $guarantee = Guarantee::create([
                    'rental_id' => $rental->id, 'type' => $g['type'], 'holder_name' => trim($g['holderName']),
                    'number_enc' => $number, 'number_masked' => GuaranteePolicy::mask($number), 'status' => 'submitted',
                ]);
                // Foto dokumen adalah data pribadi: disimpan di disk privat.
                $guarantee->update(['photo_path' => $g['photo']->storeAs(
                    "guarantees/{$rental->id}", "{$guarantee->id}.".$g['photo']->extension(), 'local')]);
            }
            $rental->logs()->create([
                'from' => null, 'to' => 'pendingConfirmation', 'actor_name' => $customer->name, 'at' => now(),
            ]);
            DB::table('idempotency_keys')->insert([
                'key' => $idempotencyKey, 'customer_id' => $customer->id, 'rental_id' => $rental->id,
            ]);

            return $rental;
        });
    }

    /** Mis. "INV-20261002-0007". Nomor urut diambil dari baris penghitung yang dikunci. */
    private function nextInvoiceCode(): string
    {
        DB::table('counters')->insertOrIgnore(['name' => 'invoice', 'value' => 0]);
        $value = DB::table('counters')->where('name', 'invoice')->lockForUpdate()->value('value') + 1;
        DB::table('counters')->where('name', 'invoice')->update(['value' => $value]);

        return 'INV-'.now()->format('Ymd').'-'.str_pad((string) $value, 4, '0', STR_PAD_LEFT);
    }
}
