<?php

namespace Tests\Feature;

use App\Models\Equipment;
use App\Models\Guarantee;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SeedTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

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

    public function test_document_numbers_are_encrypted_at_rest(): void
    {
        $raw = DB::table('guarantees')->where('id', 'g-1')->value('number_enc');
        $this->assertStringNotContainsString('3573011204020001', $raw);
        $this->assertSame('3573011204020001', Guarantee::find('g-1')->number_enc);
        $this->assertSame('••••••••••••0001', Guarantee::find('g-1')->number_masked);
    }
}
