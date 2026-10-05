<?php

namespace Database\Seeders;

use App\Models\Equipment;
use App\Models\Provider;
use App\Models\Review;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;

/**
 * Enam toko contoh tambahan, supaya katalog dan peta tidak hanya berisi dua toko. Boleh dijalankan berulang kali
 * dan di database yang sudah berisi data: baris yang sudah ada tidak digandakan dan data lain tidak disentuh.
 *
 *     php artisan db:seed --class=MoreStoresSeeder --force
 *
 * Nama toko, alamat, dan rekening adalah contoh. Foto memakai berkas yang sama dengan toko demo awal. Aplikasi
 * mode data lokal (rentgear_app/lib/data/seed.dart) tidak memuat toko-toko ini.
 */
class MoreStoresSeeder extends Seeder
{
    /** Stok per ukuran untuk sepatu. */
    private const SHOE_SIZES = [['39', 1], ['40', 2], ['41', 2], ['42', 2], ['43', 1]];

    public function run(): void
    {
        $now = CarbonImmutable::now();

        foreach ($this->stores() as $slug => $store) {
            $providerId = "p-$slug";
            $owner = User::firstOrCreate(['id' => "u-$slug"], [
                'name' => $store['owner'], 'email' => "$slug@rentgear.id", 'phone' => $store['phone'],
                'role' => User::PROVIDER, 'city' => $store['city'], 'provider_id' => $providerId, 'password' => 'password',
            ]);
            Provider::firstOrCreate(['id' => $providerId], [
                'owner_id' => $owner->id, 'business_name' => $store['name'], 'city' => $store['city'],
                'address' => $store['address'], 'latitude' => $store['at'][0], 'longitude' => $store['at'][1],
                'status' => Provider::VERIFIED, 'bank_account' => $store['bank'], 'accepted_types' => $store['accepts'],
            ]);

            foreach ($store['equipment'] as [$key, $category, $name, $brand, $description, $price, $deposit, $stock, $capacity, $weight, $rating, $condition, $photos]) {
                $equipment = Equipment::firstOrCreate(['id' => "e-$slug-$key"], [
                    'provider_id' => $providerId, 'category_id' => $category, 'name' => $name, 'brand' => $brand,
                    'description' => $description, 'price_per_day' => $price, 'deposit_amount' => $deposit,
                    'stock' => $category === 'sepatu' ? 0 : $stock, 'capacity_person' => $capacity,
                    'weight_gram' => $weight, 'rating' => $rating, 'condition_score' => $condition,
                ]);
                foreach ($photos as $i => $file) {
                    $equipment->photos()->firstOrCreate(
                        ['id' => "{$equipment->id}-photo-".($i + 1)],
                        ['path' => $this->publishPhoto($file), 'sort' => $i + 1],
                    );
                }
                if ($category === 'sepatu') {
                    foreach (self::SHOE_SIZES as $sort => [$label, $sizeStock]) {
                        $equipment->sizes()->firstOrCreate(['label' => $label], ['stock' => $sizeStock, 'sort' => $sort]);
                    }
                }
            }

            foreach ($store['reviews'] as $i => [$customer, $stars, $comment, $day, $equipmentName]) {
                Review::firstOrCreate(['id' => "rv-$slug-".($i + 1)], [
                    'provider_id' => $providerId, 'customer_name' => $customer, 'rating' => $stars, 'comment' => $comment,
                    'at' => $now->startOfDay()->addDays($day), 'equipment_name' => $equipmentName,
                ]);
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
     * Tiap alat: kunci, kategori, nama, merek, deskripsi, harga per hari, deposit, stok, kapasitas, berat (gram),
     * rating, kondisi, foto. Tiap ulasan: nama, bintang, komentar, hari (relatif hari ini), nama alat.
     */
    private function stores(): array
    {
        return [
            'bromo' => [
                'name' => 'Bromo Adventure Gear', 'owner' => 'Hendra Kusuma', 'phone' => '081234567811',
                'city' => 'Probolinggo', 'address' => 'Jl. Raya Bromo No. 21, Sukapura, Probolinggo', 'at' => [-7.9193, 113.0206],
                'bank' => 'BNI 0456 7788 21 a.n. Hendra Kusuma', 'accepts' => ['ktp', 'sim', 'ktm'],
                'equipment' => [
                    ['tenda4', 'tenda', 'Tenda Dome 4 Orang Double Layer', 'Consina', 'Tenda 4 orang dengan teras depan. Flysheet tahan hujan, sudah termasuk pasak dan tali.', 50000, 100000, 4, 4, 3400, 4.6, 86, ['dome4_2.jpg', 'dome4_3.jpg', 'dome4_1.jpg']],
                    ['sb', 'sleeping-bag', 'Sleeping Bag Mummy', 'Eiger', 'Sleeping bag model mummy untuk suhu dingin Bromo, nyaman sampai 5°C.', 20000, 40000, 10, 1, 1100, 4.7, 88, ['sbpolar_2.jpg', 'sbpolar_1.jpg']],
                    ['headlamp', 'penerangan', 'Headlamp LED Rechargeable', 'Eiger', 'Headlamp isi ulang lewat USB, tahan sekitar 8 jam di mode normal.', 12000, 25000, 12, null, 85, 4.5, 90, ['headlamp_2.jpg', 'headlamp_1.jpg']],
                    ['kompor', 'masak', 'Kompor Lipat Mini + 1 Gas', 'Kovea', 'Kompor lipat ringkas, termasuk 1 tabung gas kecil.', 18000, 40000, 6, null, 380, 4.4, 84, ['kompor_2.jpg', 'kompor_1.jpg']],
                ],
                'reviews' => [
                    ['Dimas Saputra', 5, 'Sleeping bag hangat, cocok untuk sunrise di Penanjakan.', -3, 'Sleeping Bag Mummy'],
                    ['Nadia Rahma', 4, 'Tenda lengkap dan bersih. Lokasi toko mudah dicari.', -11, 'Tenda Dome 4 Orang Double Layer'],
                ],
            ],
            'welirang' => [
                'name' => 'Welirang Outdoor', 'owner' => 'Bayu Setiawan', 'phone' => '081234567812',
                'city' => 'Pasuruan', 'address' => 'Jl. Raya Tretes No. 8, Prigen, Pasuruan', 'at' => [-7.6958, 112.6331],
                'bank' => 'Mandiri 1440 0098 7712 a.n. Bayu Setiawan', 'accepts' => ['ktp', 'sim', 'kartuKeluarga'],
                'equipment' => [
                    ['carrier', 'carrier', 'Carrier 55L + Rain Cover', 'Eiger', 'Carrier 55 liter dengan frame internal dan sabuk pinggang empuk.', 32000, 75000, 6, null, 1700, 4.6, 87, ['carrier60_2.jpg', 'carrier60_3.jpg', 'carrier60_1.jpg']],
                    ['tenda2', 'tenda', 'Tenda Ultralight 2 Orang', 'Naturehike', 'Tenda ringan 1,6 kg untuk jalur Arjuno-Welirang. Dua pintu, dua teras.', 55000, 150000, 3, 2, 1600, 4.8, 92, ['ul2p_2.jpg', 'ul2p_3.jpg', 'ul2p_1.jpg']],
                    ['sepatu', 'sepatu', 'Sepatu Trekking Mid', 'Eiger', 'Sepatu mid-cut dengan sol bergerigi untuk jalur berbatu. Pilih ukuran sesuai sepatu harian Anda.', 35000, 100000, 0, null, 1050, 4.5, 80, ['sepatu_2.jpg', 'sepatu_3.jpg', 'sepatu_1.jpg']],
                    ['nesting', 'masak', 'Nesting 3 Susun', 'DS', 'Panci susun alumunium untuk 2 sampai 3 orang, ringan dan mudah dibersihkan.', 12000, 30000, 8, null, 550, 4.3, 82, ['nesting_2.jpg', 'nesting_3.jpg', 'nesting_1.jpg']],
                ],
                'reviews' => [
                    ['Rizky Hidayat', 5, 'Tenda ultralight ringan dan kering. Proses sewa cepat.', -5, 'Tenda Ultralight 2 Orang'],
                    ['Putri Anggraini', 4, 'Carrier nyaman. Sepatu ukuran 40 sedang kosong waktu itu.', -17, 'Carrier 55L + Rain Cover'],
                ],
            ],
            'kawi' => [
                'name' => 'Kawi Camp Supply', 'owner' => 'Wahyu Nugraha', 'phone' => '081234567813',
                'city' => 'Malang', 'address' => 'Jl. Panji No. 45, Kepanjen, Malang', 'at' => [-8.1301, 112.5729],
                'bank' => 'BRI 0051 01 002345 50 7 a.n. Wahyu Nugraha', 'accepts' => ['ktp', 'ktm'],
                'equipment' => [
                    ['family', 'tenda', 'Tenda Keluarga 6 Orang', 'Great Outdoor', 'Tenda besar dengan dua ruang untuk camping keluarga di bumi perkemahan.', 75000, 200000, 2, 6, 6800, 4.5, 85, ['family6_2.jpg', 'family6_1.jpg']],
                    ['sb', 'sleeping-bag', 'Sleeping Bag Polar Tebal', 'Consina', 'Bahan polar tebal, hangat untuk malam di ketinggian sedang.', 15000, 30000, 10, 1, 950, 4.4, 83, ['sbpolar_3.jpg', 'sbpolar_1.jpg']],
                    ['kompor', 'masak', 'Kompor Portable + 1 Gas', 'Hi-Cook', 'Kompor portable dengan pemantik otomatis, termasuk 1 tabung gas.', 18000, 50000, 5, null, 1400, 4.3, 86, ['kompor_1.jpg', 'kompor_2.jpg']],
                    ['headlamp', 'penerangan', 'Headlamp 200 Lumen', 'Energizer', 'Headlamp baterai AAA dengan tiga mode cahaya.', 8000, 20000, 9, null, 80, 4.2, 81, ['headlamp_1.jpg', 'headlamp_2.jpg']],
                ],
                'reviews' => [
                    ['Bagas Pratama', 5, 'Tenda keluarga luas, anak-anak senang. Harga wajar.', -8, 'Tenda Keluarga 6 Orang'],
                    ['Mega Lestari', 4, 'Kompor berfungsi baik. Gas cadangan bisa dibeli di toko.', -21, 'Kompor Portable + 1 Gas'],
                ],
            ],
            'ijen' => [
                'name' => 'Ijen Trekker Rent', 'owner' => 'Ayu Permatasari', 'phone' => '081234567814',
                'city' => 'Banyuwangi', 'address' => 'Jl. Raya Licin No. 17, Licin, Banyuwangi', 'at' => [-8.1873, 114.2674],
                'bank' => 'BCA 1820 3344 91 a.n. Ayu Permatasari', 'accepts' => ['ktp', 'sim', 'paspor'],
                'equipment' => [
                    ['headlamp', 'penerangan', 'Headlamp 350 Lumen', 'Petzl', 'Headlamp terang untuk pendakian malam ke kawah, tahan cipratan air.', 12000, 30000, 15, null, 95, 4.8, 93, ['headlamp_1.jpg', 'headlamp_2.jpg']],
                    ['sepatu', 'sepatu', 'Sepatu Hiking Waterproof', 'Merrell', 'Sepatu tahan air dengan sol Vibram untuk jalur berpasir dan berbatu.', 40000, 100000, 0, null, 1100, 4.7, 88, ['sepatu_3.jpg', 'sepatu_1.jpg', 'sepatu_2.jpg']],
                    ['carrier', 'carrier', 'Daypack 30L', 'Deuter', 'Tas harian 30 liter dengan rain cover, pas untuk pendakian pulang-pergi.', 20000, 50000, 8, null, 900, 4.6, 90, ['carrier60_3.jpg', 'carrier60_1.jpg']],
                    ['tenda2', 'tenda', 'Tenda 2 Orang Single Layer', 'Great Outdoor', 'Tenda ringkas 2 orang untuk berkemah di Paltuding.', 35000, 80000, 4, 2, 2100, 4.3, 82, ['ul2p_3.jpg', 'ul2p_1.jpg']],
                ],
                'reviews' => [
                    ['Kevin Wijaya', 5, 'Headlamp sangat terang untuk naik jam 2 pagi. Baterai penuh.', -2, 'Headlamp 350 Lumen'],
                    ['Salsa Amalia', 5, 'Sepatu pas dan tidak licin di jalur turun kawah.', -9, 'Sepatu Hiking Waterproof'],
                    ['Arif Budiman', 4, 'Daypack bagus. Antrean ambil barang agak lama saat akhir pekan.', -19, 'Daypack 30L'],
                ],
            ],
            'lawu' => [
                'name' => 'Lawu Summit Gear', 'owner' => 'Joko Purnomo', 'phone' => '081234567815',
                'city' => 'Magetan', 'address' => 'Jl. Raya Sarangan No. 30, Plaosan, Magetan', 'at' => [-7.6772, 111.2196],
                'bank' => 'BRI 0077 01 004512 53 2 a.n. Joko Purnomo', 'accepts' => ['ktp', 'sim', 'ktm', 'kartuKeluarga'],
                'equipment' => [
                    ['tenda4', 'tenda', 'Tenda Dome 4 Orang', 'Rei', 'Tenda 4 orang rangka fiber, tahan angin punggungan Lawu.', 45000, 100000, 5, 4, 3300, 4.5, 84, ['dome4_3.jpg', 'dome4_1.jpg', 'dome4_2.jpg']],
                    ['carrier', 'carrier', 'Carrier 70L', 'Consina', 'Carrier 70 liter untuk pendakian dua malam, back system bisa disetel.', 38000, 80000, 4, null, 2100, 4.6, 86, ['carrier60_1.jpg', 'carrier60_2.jpg']],
                    ['sb', 'sleeping-bag', 'Sleeping Bag Dacron', 'Rei', 'Isi dacron, hangat sampai sekitar 8°C, bisa dibuka jadi selimut.', 15000, 30000, 12, 1, 1000, 4.4, 80, ['sbpolar_1.jpg', 'sbpolar_3.jpg']],
                    ['nesting', 'masak', 'Cooking Set 2 Orang', 'Naturehike', 'Panci, wajan, dan mangkuk lipat untuk 2 orang.', 15000, 35000, 6, null, 480, 4.5, 88, ['nesting_3.jpg', 'nesting_1.jpg']],
                ],
                'reviews' => [
                    ['Galih Ramadhan', 5, 'Carrier 70L kuat dan nyaman untuk naik lewat Cemoro Sewu.', -7, 'Carrier 70L'],
                    ['Indah Kartika', 4, 'Tenda bagus. Ada satu pasak bengkok tapi masih bisa dipakai.', -14, 'Tenda Dome 4 Orang'],
                ],
            ],
            'basecamp' => [
                'name' => 'Basecamp Surabaya Outdoor', 'owner' => 'Fitri Handayani', 'phone' => '081234567816',
                'city' => 'Surabaya', 'address' => 'Jl. Ngagel Jaya Selatan No. 14, Surabaya', 'at' => [-7.2896, 112.7556],
                'bank' => 'BCA 5120 7788 40 a.n. Fitri Handayani', 'accepts' => ['ktp', 'sim', 'ktm', 'paspor'],
                'equipment' => [
                    ['family', 'tenda', 'Tenda Family 6 Orang', 'Great Outdoor', 'Tenda keluarga dengan ruang tamu, cocok untuk camping ground.', 85000, 200000, 3, 6, 7000, 4.6, 89, ['family6_1.jpg', 'family6_2.jpg']],
                    ['carrier', 'carrier', 'Carrier 60L', 'Deuter', 'Carrier 60 liter dengan ventilasi punggung dan kompartemen bawah.', 40000, 100000, 5, null, 1900, 4.8, 93, ['carrier60_2.jpg', 'carrier60_1.jpg', 'carrier60_3.jpg']],
                    ['kompor', 'masak', 'Kompor Windproof + 1 Gas', 'Fire Maple', 'Kompor tahan angin dengan pemantik, termasuk 1 tabung gas.', 22000, 50000, 6, null, 420, 4.7, 91, ['kompor_2.jpg', 'kompor_1.jpg']],
                    ['sb', 'sleeping-bag', 'Sleeping Bag Down Ringan', 'Naturehike', 'Isi bulu angsa, ringan dan ringkas, nyaman sampai 3°C.', 30000, 75000, 6, 1, 600, 4.8, 94, ['sbpolar_2.jpg', 'sbpolar_3.jpg']],
                ],
                'reviews' => [
                    ['Yusuf Maulana', 5, 'Barang terawat dan lengkap. Bisa ambil malam sebelum berangkat.', -4, 'Carrier 60L'],
                    ['Citra Dewanti', 5, 'Sleeping bag down ringan sekali dan hangat.', -13, 'Sleeping Bag Down Ringan'],
                ],
            ],
        ];
    }
}
