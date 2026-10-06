<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\Guarantee;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use Database\Seeders\DemoSeeder;
use Database\Seeders\MoreGearSeeder;
use Database\Seeders\MoreStoresSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SeedTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    protected string $seeder = DemoSeeder::class;

    public function test_demo_data_matches_the_flutter_seed(): void
    {
        $this->assertSame(6, User::count());
        $this->assertSame(3, Provider::count());
        $this->assertSame(6, DB::table('categories')->count());
        $this->assertSame(9, Equipment::count());
        $this->assertSame(6, Rental::count());
        $this->assertSame(6, Review::count());
        $this->assertSame(1, DB::table('follows')->count());

        $sepatu = Equipment::with('sizes')->find('e-sepatu');
        $this->assertSame(['39', '40', '41', '42', '43', '44'], $sepatu->sizes->pluck('label')->all());
        $this->assertSame(9, $sepatu->stockFor(null));
        $this->assertSame(2, $sepatu->stockFor('41'));

        $rental = Rental::with('guarantees', 'logs')->find('r-4');
        $this->assertSame('pickedUp', $rental->status);
        $this->assertSame('held', $rental->guarantees->first()->status);
        $this->assertCount(4, $rental->logs);
    }

    public function test_more_stores_can_be_added_to_a_database_in_use_without_duplicates(): void
    {
        $this->seed(MoreStoresSeeder::class);
        $this->seed(MoreStoresSeeder::class);

        $this->assertSame(9, Provider::count());
        $this->assertSame(8, Provider::where('status', Provider::VERIFIED)->count());
        $this->assertSame(33, Equipment::count());
        $this->assertSame(12, User::count());
        $this->assertSame(19, Review::count());
        $this->assertSame(6, Rental::count());

        foreach (Equipment::with('photos', 'sizes')->where('id', 'like', 'e-%-%')->whereNotIn('provider_id', ['p-arjuna', 'p-semeru', 'p-puncak'])->get() as $e) {
            $this->assertGreaterThanOrEqual(2, $e->photos->count(), $e->id);
            $this->assertGreaterThan(0, $e->stockFor(null), $e->id);
        }
        $this->assertSame(['39', '40', '41', '42', '43'], Equipment::find('e-ijen-sepatu')->sizes->pluck('label')->all());
    }

    public function test_more_gear_is_added_to_existing_stores_without_duplicates(): void
    {
        $this->seed(MoreStoresSeeder::class);
        $this->seed(MoreGearSeeder::class);
        $this->seed(MoreGearSeeder::class);

        $this->assertSame(58, Equipment::count());
        $this->assertSame(7, DB::table('categories')->count());
        $this->assertSame(21, Equipment::where('category_id', MoreGearSeeder::CATEGORY)->count());
        $this->assertSame(9, Provider::count());
        $this->assertSame(6, Rental::count());

        $files = collect(File::files(base_path('../rentgear_app/assets/equipment')))->map->getFilename();
        $credited = collect(json_decode(File::get(base_path('../rentgear_app/assets/equipment/credits.json')), true))->pluck('file');
        foreach (DB::table('equipment_photos')->pluck('path') as $path) {
            $this->assertContains(basename($path), $files, $path);
            $this->assertContains(basename($path), $credited, $path);
        }

        // Penyewa melihat kategori dan alat baru di katalog, lengkap dengan foto dan stok.
        Sanctum::actingAs(User::findOrFail('u-budi'));
        $this->assertContains('Perlengkapan', $this->getJson('/api/v1/categories')->json('data.*.name'));
        $catalog = collect($this->getJson('/api/v1/equipment?categoryId=perlengkapan')->json('data'));
        $this->assertCount(21, $catalog);
        foreach ($catalog as $item) {
            $this->assertNotEmpty($item['photos'], $item['id']);
            $this->assertGreaterThan(0, $item['stock'], $item['id']);
        }
    }

    public function test_document_numbers_are_encrypted_at_rest(): void
    {
        $raw = DB::table('guarantees')->where('id', 'g-1')->value('number_enc');
        $this->assertStringNotContainsString('3573011204020001', $raw);
        $this->assertSame('3573011204020001', Guarantee::find('g-1')->number_enc);
        $this->assertSame('••••••••••••0001', Guarantee::find('g-1')->number_masked);
    }
}
