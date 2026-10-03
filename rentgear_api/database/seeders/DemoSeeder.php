<?php

namespace Database\Seeders;

use App\Domain\Guarantee\GuaranteePolicy;
use App\Models\Category;
use App\Models\Equipment;
use App\Models\Guarantee;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;

/**
 * Data contoh untuk demo, sama dengan rentgear_app/lib/data/seed.dart.
 * Semua akun memakai password `password`.
 */
class DemoSeeder extends Seeder
{
    private CarbonImmutable $now;

    public function run(): void
    {
        $this->now = CarbonImmutable::now();

        $this->users();
        $this->providers();
        $this->catalog();
        $this->rentals();
        $this->reviewsAndFollows();
    }

    private function day(int $offset): CarbonImmutable
    {
        return $this->now->startOfDay()->addDays($offset);
    }

    private function users(): void
    {
        $rows = [
            ['u-budi', 'Budi Santoso', 'budi@rentgear.id', '081234567801', User::CUSTOMER, 'Malang', null],
            ['u-rina', 'Rina Putri', 'rina@rentgear.id', '081234567802', User::CUSTOMER, 'Surabaya', null],
            ['u-sari', 'Sari Wulandari', 'sari@rentgear.id', '081234567803', User::PROVIDER, 'Malang', 'p-arjuna'],
            ['u-dewi', 'Dewi Lestari', 'dewi@rentgear.id', '081234567804', User::PROVIDER, 'Lumajang', 'p-semeru'],
            ['u-agus', 'Agus Pratama', 'agus@rentgear.id', '081234567805', User::PROVIDER, 'Batu', 'p-puncak'],
            ['u-admin', 'Admin RentGear', 'admin@rentgear.id', '081234567800', User::ADMIN, 'Malang', null],
        ];
        foreach ($rows as [$id, $name, $email, $phone, $role, $city, $providerId]) {
            User::create([
                'id' => $id, 'name' => $name, 'email' => $email, 'phone' => $phone, 'role' => $role,
                'city' => $city, 'provider_id' => $providerId,
                // Di server publik, password admin diganti lewat DEMO_ADMIN_PASSWORD.
                'password' => $role === User::ADMIN ? config('services.demo.admin_password') : 'password',
            ]);
        }
    }

    private function providers(): void
    {
        Provider::create([
            'id' => 'p-arjuna', 'owner_id' => 'u-sari', 'business_name' => 'Arjuna Outdoor', 'city' => 'Malang',
            'address' => 'Jl. Soekarno Hatta No. 12, Malang', 'latitude' => -7.9396, 'longitude' => 112.6289,
            'status' => 'verified', 'bank_account' => 'BCA 0231 4455 67 a.n. Arjuna Outdoor',
            'accepted_types' => ['ktp', 'sim', 'ktm', 'kartuKeluarga'],
        ]);
        Provider::create([
            'id' => 'p-semeru', 'owner_id' => 'u-dewi', 'business_name' => 'Semeru Camp Rent', 'city' => 'Lumajang',
            'address' => 'Jl. Raya Senduro No. 5, Lumajang', 'latitude' => -8.1049, 'longitude' => 113.0868,
            'status' => 'verified', 'bank_account' => 'BRI 0012 01 000456 30 1 a.n. Dewi Lestari',
            'accepted_types' => ['ktp', 'ktm', 'ijazah', 'paspor'], 'high_value_threshold' => 750000,
        ]);
        Provider::create([
            'id' => 'p-puncak', 'owner_id' => 'u-agus', 'business_name' => 'Puncak Outdoor', 'city' => 'Batu',
            'address' => 'Jl. Panglima Sudirman No. 88, Batu', 'latitude' => -7.8707, 'longitude' => 112.5269,
            'status' => 'pending', 'accepted_types' => ['ktp', 'sim'],
        ]);
    }

    private function catalog(): void
    {
        $categories = [
            'tenda' => 'Tenda', 'carrier' => 'Carrier', 'sleeping-bag' => 'Sleeping Bag',
            'masak' => 'Alat Masak', 'penerangan' => 'Penerangan', 'sepatu' => 'Sepatu',
        ];
        $sort = 0;
        foreach ($categories as $id => $name) {
            Category::create(['id' => $id, 'name' => $name, 'sort' => $sort++]);
        }

        // id, toko, kategori, nama, merek, deskripsi, harga, deposit, stok, kapasitas, berat, rating, kondisi, foto, jumlah foto
        $rows = [
            ['e-dome4', 'p-arjuna', 'tenda', 'Tenda Dome 4 Orang', 'Eiger', 'Tenda double layer, frame alumunium, tahan angin gunung. Cocok untuk rombongan 3-4 orang.', 45000, 100000, 3, 4, 3200, 4.7, 88, 'dome4', 3],
            ['e-carrier60', 'p-arjuna', 'carrier', 'Carrier 60L', 'Consina', 'Carrier 60 liter dengan back system adjustable dan rain cover.', 35000, 75000, 5, null, 1800, 4.6, 85, 'carrier60', 3],
            ['e-sbpolar', 'p-arjuna', 'sleeping-bag', 'Sleeping Bag Polar', 'Rei', 'Sleeping bag bahan polar, suhu nyaman hingga 10°C.', 15000, 30000, 8, 1, 900, 4.5, 80, 'sbpolar', 3],
            ['e-kompor', 'p-arjuna', 'masak', 'Kompor Portable + 1 Gas', 'Kovea', 'Kompor lipat dengan pemantik otomatis, termasuk 1 tabung gas.', 20000, 50000, 4, null, 450, 4.4, 90, 'kompor', 2],
            ['e-ul2p', 'p-semeru', 'tenda', 'Tenda Ultralight 2 Orang', 'Naturehike', 'Tenda ultralight 1,5 kg untuk pendakian cepat. Double wall, 20D nylon.', 60000, 150000, 2, 2, 1500, 4.9, 95, 'ul2p', 3],
            ['e-headlamp', 'p-semeru', 'penerangan', 'Headlamp 300 Lumen', 'Petzl', 'Headlamp baterai AAA, mode red light, tahan cipratan air.', 10000, 25000, 10, null, 90, 4.7, 92, 'headlamp', 2],
            ['e-sepatu', 'p-semeru', 'sepatu', 'Sepatu Hiking Waterproof', 'Merrell', 'Sepatu mid-cut waterproof dengan sol Vibram. Pilih ukuran sesuai ukuran sepatu harian Anda.', 40000, 100000, 0, null, 1100, 4.6, 82, 'sepatu', 3],
            ['e-nesting', 'p-semeru', 'masak', 'Nesting Cooking Set', 'DS', 'Set panci & wajan alumunium untuk 2-3 orang.', 15000, 30000, 6, null, 600, 4.3, 78, 'nesting', 3],
            ['e-family6', 'p-puncak', 'tenda', 'Tenda Family 6 Orang', 'Great Outdoor', 'Tenda besar untuk camping keluarga.', 80000, 200000, 2, 6, 6500, 0, 90, 'family6', 2],
        ];
        foreach ($rows as [$id, $provider, $category, $name, $brand, $description, $price, $deposit, $stock, $capacity, $weight, $rating, $condition, $photo, $photoCount]) {
            $equipment = Equipment::create([
                'id' => $id, 'provider_id' => $provider, 'category_id' => $category, 'name' => $name,
                'brand' => $brand, 'description' => $description, 'price_per_day' => $price,
                'deposit_amount' => $deposit, 'stock' => $stock, 'capacity_person' => $capacity,
                'weight_gram' => $weight, 'rating' => $rating, 'condition_score' => $condition,
            ]);
            for ($i = 1; $i <= $photoCount; $i++) {
                $equipment->photos()->create([
                    'id' => "$id-photo-$i", 'path' => $this->publishPhoto("{$photo}_$i.jpg"), 'sort' => $i,
                ]);
            }
        }

        foreach ([['39', 1], ['40', 2], ['41', 2], ['42', 2], ['43', 1], ['44', 1]] as $sort => [$label, $stock]) {
            Equipment::find('e-sepatu')->sizes()->create(['label' => $label, 'stock' => $stock, 'sort' => $sort]);
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

    private function rentals(): void
    {
        $this->rental('r-1', 'INV-DEMO-0001', 'u-budi', 'e-dome4', 1, 3, 5, 'pendingConfirmation',
            [['g-1', 'ktp', '3573011204020001', 'submitted', null, null]],
            [[null, 'pendingConfirmation', 'Budi Santoso']]);
        $this->rental('r-2', 'INV-DEMO-0002', 'u-rina', 'e-dome4', 2, 4, 6, 'awaitingPayment',
            [['g-2', 'ktp', '3578014507030002', 'verified', null, null]],
            [[null, 'pendingConfirmation', 'Rina Putri'], ['pendingConfirmation', 'awaitingPayment', 'Arjuna Outdoor']]);
        $this->rental('r-3', 'INV-DEMO-0003', 'u-rina', 'e-carrier60', 2, 1, 2, 'paid',
            [['g-3', 'sim', '1203-0405-000123', 'verified', null, null]],
            [[null, 'pendingConfirmation', 'Rina Putri'], ['pendingConfirmation', 'awaitingPayment', 'Arjuna Outdoor'], ['awaitingPayment', 'paid', 'Rina Putri']]);
        $this->rental('r-4', 'INV-DEMO-0004', 'u-budi', 'e-ul2p', 1, -2, 1, 'pickedUp',
            [['g-4', 'ktm', '225150200111045', 'held', -2, null]],
            [[null, 'pendingConfirmation', 'Budi Santoso'], ['pendingConfirmation', 'awaitingPayment', 'Semeru Camp Rent'], ['awaitingPayment', 'paid', 'Budi Santoso'], ['paid', 'pickedUp', 'Semeru Camp Rent']]);
        $this->rental('r-5', 'INV-DEMO-0005', 'u-budi', 'e-sbpolar', 2, -10, -8, 'completed',
            [['g-5', 'ktp', '3573011204020001', 'returned', -10, -8]],
            [[null, 'pendingConfirmation', 'Budi Santoso'], ['pendingConfirmation', 'awaitingPayment', 'Arjuna Outdoor'], ['awaitingPayment', 'paid', 'Budi Santoso'], ['paid', 'pickedUp', 'Arjuna Outdoor'], ['pickedUp', 'returned', 'Arjuna Outdoor'], ['returned', 'completed', 'Arjuna Outdoor']]);
        // Sudah lewat tanggal selesai: `rentgear:run-jobs` menandainya "Terlambat",
        // sehingga denda keterlambatan bisa didemokan.
        $this->rental('r-6', 'INV-DEMO-0006', 'u-rina', 'e-headlamp', 2, -5, -2, 'pickedUp',
            [['g-6', 'ktp', '3578014507030002', 'held', -5, null]],
            [[null, 'pendingConfirmation', 'Rina Putri'], ['pendingConfirmation', 'awaitingPayment', 'Semeru Camp Rent'], ['awaitingPayment', 'paid', 'Rina Putri'], ['paid', 'pickedUp', 'Semeru Camp Rent']]);
    }

    /**
     * Tiap jaminan: id, jenis, nomor, status, hari dipegang, hari dikembalikan.
     * Tiap riwayat: dari, ke, pelaku.
     *
     * @param  array<int, array{0: string, 1: string, 2: string, 3: string, 4: ?int, 5: ?int}>  $guarantees
     * @param  array<int, array{0: ?string, 1: string, 2: string}>  $history
     */
    private function rental(string $id, string $invoice, string $customerId, string $equipmentId, int $qty,
        int $startOffset, int $endOffset, string $status, array $guarantees, array $history): void
    {
        $customer = User::find($customerId);
        $equipment = Equipment::with('provider', 'photos')->find($equipmentId);
        // Transaksi yang masih berjalan dibuat "barusan" agar job otomatis
        // (kedaluwarsa 12 jam / belum bayar 24 jam) tidak langsung mengubahnya.
        $created = $startOffset >= 0 ? $this->now->subHours(2) : $this->day(min(-1, $startOffset - 2));

        $rental = Rental::create([
            'id' => $id, 'invoice_code' => $invoice, 'customer_id' => $customer->id, 'customer_name' => $customer->name,
            'provider_id' => $equipment->provider_id, 'provider_name' => $equipment->provider->business_name,
            'equipment_id' => $equipment->id, 'equipment_name' => $equipment->name,
            'category_id' => $equipment->category_id, 'qty' => $qty, 'photo_path' => $equipment->photos->first()?->path,
            'start_date' => $this->day($startOffset), 'end_date' => $this->day($endOffset),
            'price_per_day_snapshot' => $equipment->price_per_day, 'deposit_snapshot' => $equipment->deposit_amount,
            'status' => $status, 'created_at' => $created, 'updated_at' => $created,
        ]);

        foreach ($guarantees as [$guaranteeId, $type, $number, $guaranteeStatus, $heldDay, $returnedDay]) {
            Guarantee::create([
                'id' => $guaranteeId, 'rental_id' => $rental->id, 'type' => $type, 'holder_name' => $customer->name,
                'number_enc' => $number, 'number_masked' => GuaranteePolicy::mask($number), 'status' => $guaranteeStatus,
                'held_at' => $heldDay === null ? null : $this->day($heldDay),
                'returned_at' => $returnedDay === null ? null : $this->day($returnedDay),
            ]);
        }

        foreach ($history as $i => [$from, $to, $actor]) {
            $rental->logs()->create([
                'from' => $from, 'to' => $to, 'actor_name' => $actor, 'at' => $created->addMinutes($i * 20),
            ]);
        }
    }

    /** Ulasan dari penyewa lama, supaya halaman toko tidak kosong saat demo. */
    private function reviewsAndFollows(): void
    {
        $rows = [
            ['rv-1', 'p-arjuna', 'Andi Prasetyo', 5, 'Tenda bersih dan kering, pasak lengkap. Serah terima cepat.', -6, 'Tenda Dome 4 Orang'],
            ['rv-2', 'p-arjuna', 'Sinta Maharani', 4, 'Carrier nyaman dipakai. Rain cover agak kotor waktu diambil.', -15, 'Carrier 60L'],
            ['rv-3', 'p-arjuna', 'Yoga Firmansyah', 5, 'Kompor menyala normal dan gasnya masih penuh.', -28, 'Kompor Portable + 1 Gas'],
            ['rv-4', 'p-semeru', 'Raka Aditya', 5, 'Tenda ultralight ringan sekali, cocok untuk pendakian cepat.', -4, 'Tenda Ultralight 2 Orang'],
            ['rv-5', 'p-semeru', 'Laras Wijayanti', 5, 'Sepatu sesuai ukuran dan tidak bau. Pemilik ramah.', -12, 'Sepatu Hiking Waterproof'],
            ['rv-6', 'p-semeru', 'Fajar Nugroho', 4, 'Headlamp terang. Baterai cadangan tidak disertakan.', -20, 'Headlamp 300 Lumen'],
        ];
        foreach ($rows as [$id, $provider, $name, $rating, $comment, $day, $equipment]) {
            Review::create([
                'id' => $id, 'provider_id' => $provider, 'customer_name' => $name, 'rating' => $rating,
                'comment' => $comment, 'at' => $this->day($day), 'equipment_name' => $equipment,
            ]);
        }

        DB::table('follows')->insert(['customer_id' => 'u-rina', 'provider_id' => 'p-arjuna']);
    }
}
