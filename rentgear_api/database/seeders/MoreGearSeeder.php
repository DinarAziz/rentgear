<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Equipment;
use App\Models\Provider;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;

/**
 * Tujuh jenis alat baru (matras, trekking pole, hammock, kursi lipat, flysheet, lentera, ponco) untuk toko yang
 * sudah ada, dan kategori "Perlengkapan". Boleh dijalankan berulang kali dan di database yang sudah berisi data:
 * baris yang sudah ada tidak digandakan dan data lain tidak disentuh. Toko yang tidak ada dilewati.
 *
 *     php artisan db:seed --class=MoreGearSeeder --force
 *
 * Nama alat, merek, dan harga adalah contoh. Fotonya dari Wikimedia Commons; pembuat dan lisensinya ada di
 * rentgear_app/assets/equipment/credits.json. Aplikasi mode data lokal tidak memuat alat-alat ini.
 */
class MoreGearSeeder extends Seeder
{
    public const CATEGORY = 'perlengkapan';

    public function run(): void
    {
        Category::firstOrCreate(['id' => self::CATEGORY], ['name' => 'Perlengkapan', 'sort' => 6]);

        foreach ($this->gear() as $slug => $items) {
            $providerId = "p-$slug";
            if (! Provider::whereKey($providerId)->exists()) {
                continue;
            }
            foreach ($items as [$key, $category, $name, $brand, $description, $price, $deposit, $stock, $capacity, $weight, $rating, $condition, $photos]) {
                $equipment = Equipment::firstOrCreate(['id' => "e-$slug-$key"], [
                    'provider_id' => $providerId, 'category_id' => $category, 'name' => $name, 'brand' => $brand,
                    'description' => $description, 'price_per_day' => $price, 'deposit_amount' => $deposit,
                    'stock' => $stock, 'capacity_person' => $capacity, 'weight_gram' => $weight,
                    'rating' => $rating, 'condition_score' => $condition,
                ]);
                foreach ($photos as $i => $file) {
                    $equipment->photos()->firstOrCreate(
                        ['id' => "{$equipment->id}-photo-".($i + 1)],
                        ['path' => $this->publishPhoto($file), 'sort' => $i + 1],
                    );
                }
            }
        }
    }

    /** Salin foto alat dari aset aplikasi Flutter ke disk publik, sekali saja. */
    private function publishPhoto(string $file): string
    {
        $path = "equipment/$file";
        $source = base_path("../rentgear_app/assets/equipment/$file");
        $disk = Storage::disk('public');
        if (! $disk->exists($path) && File::exists($source)) {
            $disk->put($path, File::get($source));
        }

        return $path;
    }

    /**
     * Per toko. Tiap alat: kunci, kategori, nama, merek, deskripsi, harga per hari, deposit, stok, kapasitas,
     * berat (gram), rating, kondisi, foto.
     */
    private function gear(): array
    {
        $extra = self::CATEGORY;

        return [
            'arjuna' => [
                ['matras', $extra, 'Matras Angin Self-Inflating', 'Naturehike', 'Matras yang mengembang sendiri, tebal 3 cm. Lebih hangat dan empuk daripada matras busa.', 12000, 30000, 8, 1, 900, 4.6, 88, ['matras_1.jpg', 'matras_2.jpg']],
                ['pole', $extra, 'Trekking Pole Aluminium (sepasang)', 'Consina', 'Sepasang tongkat lipat tiga ruas, panjang bisa disetel 65 sampai 135 cm.', 15000, 40000, 6, null, 520, 4.5, 85, ['pole_1.jpg', 'pole_2.jpg']],
                ['lentera', 'penerangan', 'Lentera Tenda LED', 'Eiger', 'Lentera gantung untuk tenda, tiga tingkat terang, tahan sekitar 20 jam.', 10000, 25000, 6, null, 350, 4.4, 86, ['lentera_1.jpg', 'lentera_2.jpg']],
            ],
            'semeru' => [
                ['hammock', $extra, 'Hammock Parasut + Tali', 'Naturehike', 'Hammock nilon parasut untuk satu orang, sudah termasuk tali pohon dan karabiner.', 15000, 35000, 5, 1, 600, 4.7, 90, ['hammock_1.jpg', 'hammock_2.jpg']],
                ['flysheet', $extra, 'Flysheet 3 x 4 m', 'Rei', 'Atap tambahan anti air untuk dapur atau teras tenda, termasuk tali dan pasak.', 15000, 40000, 4, null, 800, 4.5, 84, ['flysheet_1.jpg', 'flysheet_2.jpg']],
                ['kursi', $extra, 'Kursi Lipat Ultralight', 'Helinox', 'Kursi lipat rangka aluminium, berat di bawah 1 kg, kuat sampai 120 kg.', 18000, 50000, 4, 1, 950, 4.8, 92, ['kursi_1.jpg', 'kursi_2.jpg']],
            ],
            'bromo' => [
                ['matras', $extra, 'Matras Camping Tebal', 'Eiger', 'Matras angin untuk tidur di suhu dingin Bromo, dilengkapi kantong simpan.', 12000, 30000, 10, 1, 950, 4.5, 85, ['matras_2.jpg', 'matras_1.jpg']],
                ['ponco', $extra, 'Ponco Hujan', 'Consina', 'Ponco anti air dengan tudung, menutup badan dan carrier sekaligus.', 8000, 20000, 12, 1, 400, 4.3, 82, ['ponco_1.jpg']],
                ['pole', $extra, 'Trekking Pole Lipat (sepasang)', 'Naturehike', 'Sepasang tongkat untuk jalur pasir dan tanjakan, ujung karet bisa dilepas.', 15000, 40000, 8, null, 500, 4.6, 88, ['pole_2.jpg', 'pole_1.jpg']],
            ],
            'welirang' => [
                ['flysheet', $extra, 'Flysheet 3 x 3 m', 'Consina', 'Flysheet ringan untuk bivak atau peneduh, lapisan anti air 3000 mm.', 12000, 30000, 5, null, 650, 4.4, 83, ['flysheet_2.jpg', 'flysheet_1.jpg']],
                ['pole', $extra, 'Trekking Pole Carbon (sepasang)', 'Naturehike', 'Sepasang tongkat karbon yang ringan untuk jalur Arjuno-Welirang.', 20000, 60000, 4, null, 380, 4.8, 93, ['pole_1.jpg', 'pole_2.jpg']],
                ['lentera', 'penerangan', 'Lentera Camping Rechargeable', 'Naturehike', 'Lentera isi ulang lewat USB, bisa dipakai sebagai power bank darurat.', 12000, 30000, 5, null, 400, 4.6, 89, ['lentera_2.jpg', 'lentera_1.jpg']],
            ],
            'kawi' => [
                ['kursi', $extra, 'Kursi Lipat Camping', 'Great Outdoor', 'Kursi lipat ringkas untuk bumi perkemahan, masuk ke kantong sebesar botol.', 12000, 30000, 8, 1, 1100, 4.4, 84, ['kursi_2.jpg', 'kursi_1.jpg']],
                ['hammock', $extra, 'Hammock Single', 'Great Outdoor', 'Hammock satu orang untuk bersantai di area camping, termasuk tali pengikat.', 12000, 30000, 6, 1, 550, 4.3, 82, ['hammock_2.jpg', 'hammock_1.jpg']],
                ['matras', $extra, 'Matras Angin Keluarga', 'Great Outdoor', 'Matras angin untuk tenda keluarga, satu matras untuk satu orang.', 10000, 25000, 12, 1, 1000, 4.2, 80, ['matras_1.jpg', 'matras_2.jpg']],
            ],
            'ijen' => [
                ['ponco', $extra, 'Ponco Hujan Ringan', 'Eiger', 'Ponco tipis yang mudah dilipat, cukup untuk hujan dan angin di jalur kawah.', 8000, 20000, 15, 1, 350, 4.5, 86, ['ponco_1.jpg']],
                ['pole', $extra, 'Trekking Pole (sepasang)', 'Eiger', 'Sepasang tongkat untuk turunan berpasir ke kawah, pegangan busa.', 15000, 40000, 10, null, 540, 4.6, 87, ['pole_2.jpg', 'pole_1.jpg']],
                ['lentera', 'penerangan', 'Lentera LED Tahan Air', 'Streamlight', 'Lentera tahan cipratan air dengan mode cahaya merah, bisa digantung terbalik.', 12000, 30000, 6, null, 420, 4.7, 91, ['lentera_1.jpg', 'lentera_2.jpg']],
            ],
            'lawu' => [
                ['matras', $extra, 'Matras Self-Inflating', 'Rei', 'Matras yang mengembang sendiri untuk malam dingin di pos pendakian Lawu.', 12000, 30000, 8, 1, 920, 4.4, 83, ['matras_2.jpg', 'matras_1.jpg']],
                ['flysheet', $extra, 'Flysheet 4 x 6 m', 'Rei', 'Flysheet besar untuk rombongan, cukup menaungi dapur dan dua tenda.', 20000, 50000, 3, null, 1500, 4.5, 85, ['flysheet_1.jpg', 'flysheet_2.jpg']],
                ['ponco', $extra, 'Ponco Hujan Tebal', 'Rei', 'Ponco tebal untuk musim hujan, bisa dipakai sebagai alas darurat.', 10000, 25000, 10, 1, 480, 4.3, 81, ['ponco_1.jpg']],
            ],
            'basecamp' => [
                ['kursi', $extra, 'Kursi Lipat Ground Chair', 'Helinox', 'Kursi rendah yang stabil di tanah lunak, rangka aluminium DAC.', 20000, 60000, 5, 1, 640, 4.8, 94, ['kursi_1.jpg', 'kursi_2.jpg']],
                ['hammock', $extra, 'Hammock Double + Tali', 'Naturehike', 'Hammock lebar untuk dua orang, kuat sampai 200 kg, termasuk tali pohon.', 18000, 45000, 5, 2, 700, 4.7, 91, ['hammock_1.jpg', 'hammock_2.jpg']],
                ['lentera', 'penerangan', 'Lentera Camping 600 Lumen', 'Enbrighten', 'Lentera terang untuk area makan, baterai tahan dua malam di mode sedang.', 15000, 35000, 6, null, 600, 4.6, 90, ['lentera_2.jpg', 'lentera_1.jpg']],
                ['flysheet', $extra, 'Flysheet 3 x 4 m Silver', 'Great Outdoor', 'Flysheet berlapis perak yang menahan panas matahari di camping ground.', 15000, 40000, 6, null, 850, 4.5, 87, ['flysheet_2.jpg', 'flysheet_1.jpg']],
            ],
        ];
    }
}
