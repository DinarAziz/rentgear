<?php

namespace Tests;

use App\Models\User;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;

/** Tes fitur berjalan di atas data demo yang sama dengan aplikasi Flutter. */
abstract class ApiTestCase extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    /** Tes memakai data demo dasar; toko tambahan (`MoreStoresSeeder`) diuji tersendiri. */
    protected string $seeder = DemoSeeder::class;

    protected function as(string $name): static
    {
        Sanctum::actingAs(User::where('email', "$name@rentgear.id")->firstOrFail());

        return $this;
    }

    protected function setUp(): void
    {
        parent::setUp();
        // Foto jaminan dan bukti transfer tidak menyentuh disk sungguhan.
        Storage::fake('local');
    }

    protected function photo(): UploadedFile
    {
        return UploadedFile::fake()->image('dokumen.jpg', 40, 40);
    }

    /** Booking kompor (Arjuna Outdoor) oleh Budi dengan satu KTP, seperti helper `request()` di tes Dart. */
    protected function book(array $overrides = [], string $key = 'k1'): TestResponse
    {
        $payload = array_replace([
            'equipmentId' => 'e-kompor',
            'qty' => 1,
            'startDate' => $this->day(1),
            'endDate' => $this->day(2),
            'guarantees' => [[
                'type' => 'ktp', 'holderName' => 'Budi Santoso', 'documentNumber' => '3573011204020001',
                'photo' => $this->photo(),
            ]],
        ], $overrides);

        return $this->as('budi')->post('/api/v1/rentals', $payload, ['Idempotency-Key' => $key, 'Accept' => 'application/json']);
    }

    /** Majukan waktu lalu jalankan pekerjaan terjadwal, seperti aplikasi yang baru dibuka beberapa hari kemudian. */
    protected function afterDays(int $days): void
    {
        $this->travel($days)->days();
        $this->artisan('rentgear:run-jobs')->assertSuccessful();
    }

    protected function day(int $offset): string
    {
        return now()->startOfDay()->addDays($offset)->format('Y-m-d');
    }

    protected function assertApiError(TestResponse $response, string $code, int $status): void
    {
        $response->assertStatus($status)->assertJsonPath('success', false)->assertJsonPath('error.code', $code);
    }
}
