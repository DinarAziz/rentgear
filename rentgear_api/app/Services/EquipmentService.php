<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Equipment;
use App\Models\User;
use App\Support\ApiException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Penyedia menambah atau mengubah alatnya. Aturan sama dengan `validateEquipment` di Flutter. */
final class EquipmentService
{
    public const MAX_PHOTOS = 8;

    /** Kategori yang wajib memakai pilihan ukuran. */
    private const SIZED_CATEGORIES = ['sepatu'];

    /**
     * @param  array<string, mixed>  $data  isian alat
     * @param  array<int, array{label: string, stock: int}>  $sizes
     * @param  array<int, string|UploadedFile>  $photos  urutan foto: id foto lama, atau berkas baru
     */
    public function save(User $actor, ?string $equipmentId, array $data, array $sizes, array $photos): Equipment
    {
        if (! $actor->isProvider() || $actor->provider_id === null) {
            throw new ApiException('FORBIDDEN', 'Hanya penyedia yang bisa mengelola alat.');
        }
        $equipment = null;
        if ($equipmentId !== null) {
            $equipment = Equipment::with('photos')->find($equipmentId)
                ?? throw new ApiException('NOT_FOUND', 'Alat tidak ditemukan.');
            if ($equipment->provider_id !== $actor->provider_id) {
                throw new ApiException('FORBIDDEN', 'Alat ini bukan milik toko Anda.');
            }
        }

        // Foto lama hanya boleh dipertahankan bila memang milik alat ini.
        $kept = $equipment?->photos->keyBy('id') ?? collect();
        $photos = array_values(array_filter($photos, fn ($p) => $p instanceof UploadedFile || $kept->has($p)));

        $errors = $this->validate($data, $sizes, count($photos));
        if ($errors !== []) {
            throw new ApiException('VALIDATION', implode("\n", $errors));
        }

        return DB::transaction(function () use ($actor, $equipment, $data, $sizes, $photos, $kept) {
            $hasSizes = $sizes !== [];
            $attributes = [
                'category_id' => $data['categoryId'], 'name' => trim($data['name']), 'brand' => trim($data['brand'] ?? ''),
                'description' => trim($data['description'] ?? ''), 'price_per_day' => $data['pricePerDay'],
                'deposit_amount' => $data['depositAmount'], 'weight_gram' => $data['weightGram'],
                'stock' => $hasSizes ? 0 : (int) $data['stock'], 'capacity_person' => $data['capacityPerson'] ?? null,
                'is_active' => (bool) ($data['isActive'] ?? true),
            ];
            $equipment = $equipment === null
                ? Equipment::create([...$attributes, 'provider_id' => $actor->provider_id, 'rating' => 0, 'condition_score' => 100])
                : tap($equipment)->update($attributes);

            $equipment->sizes()->delete();
            foreach ($sizes as $sort => $size) {
                $equipment->sizes()->create(['label' => trim($size['label']), 'stock' => (int) $size['stock'], 'sort' => $sort]);
            }

            $keptIds = array_filter($photos, 'is_string');
            $equipment->photos()->whereNotIn('id', $keptIds)->delete();
            foreach ($photos as $sort => $photo) {
                if ($photo instanceof UploadedFile) {
                    $equipment->photos()->create(['path' => $photo->store("equipment/{$equipment->id}", 'public'), 'sort' => $sort]);
                } else {
                    $kept[$photo]->update(['sort' => $sort]);
                }
            }

            return $equipment->fresh(['sizes', 'photos']);
        });
    }

    /** @return array<int, string> daftar pesan kesalahan; kosong berarti valid */
    private function validate(array $data, array $sizes, int $photoCount): array
    {
        $errors = [];
        if (! Category::whereKey($data['categoryId'] ?? '')->exists()) {
            $errors[] = 'Pilih kategori alat.';
        }
        if (mb_strlen(trim((string) ($data['name'] ?? ''))) < 3) {
            $errors[] = 'Nama alat minimal 3 huruf.';
        }
        if (($data['pricePerDay'] ?? 0) <= 0) {
            $errors[] = 'Harga sewa per hari harus lebih dari 0.';
        }
        if (($data['depositAmount'] ?? 0) < 0) {
            $errors[] = 'Deposit tidak boleh negatif.';
        }
        if (($data['weightGram'] ?? 0) < 0) {
            $errors[] = 'Berat tidak boleh negatif.';
        }
        if ($photoCount === 0) {
            $errors[] = 'Tambahkan minimal 1 foto alat.';
        }
        if ($photoCount > self::MAX_PHOTOS) {
            $errors[] = 'Maksimal '.self::MAX_PHOTOS.' foto per alat.';
        }

        if (in_array($data['categoryId'] ?? '', self::SIZED_CATEGORIES, true) && $sizes === []) {
            $errors[] = 'Tambahkan minimal satu ukuran beserta stoknya.';
        }
        $labels = [];
        foreach ($sizes as $size) {
            $label = trim((string) ($size['label'] ?? ''));
            if ($label === '') {
                $errors[] = 'Label ukuran tidak boleh kosong.';
            } elseif (in_array($label, $labels, true)) {
                $errors[] = "Ukuran $label tercantum dua kali.";
            }
            $labels[] = $label;
            if (($size['stock'] ?? 0) < 0) {
                $errors[] = "Stok ukuran $label tidak boleh negatif.";
            }
        }
        $total = $sizes === [] ? (int) ($data['stock'] ?? 0) : array_sum(array_column($sizes, 'stock'));
        if ($total < 1) {
            $errors[] = 'Stok total minimal 1 unit.';
        }

        return $errors;
    }
}
