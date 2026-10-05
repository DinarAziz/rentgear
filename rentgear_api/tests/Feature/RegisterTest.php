<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Provider;
use App\Models\User;
use App\Support\Audit;
use Tests\ApiTestCase;

class RegisterTest extends ApiTestCase
{
    private function register(array $overrides = [])
    {
        return $this->postJson('/api/v1/auth/register', array_replace([
            'role' => 'customer', 'name' => 'Tania Putri', 'email' => ' Tania@Mail.com ', 'password' => 'rahasia123',
            'phone' => '081298765432', 'city' => 'Malang',
        ], $overrides));
    }

    private function store(array $overrides = []): array
    {
        return array_replace([
            'role' => 'provider', 'businessName' => 'Bromo Gear', 'address' => 'Jl. Ijen No. 3, Malang',
            'bankAccount' => 'BCA 1234567890 a.n. Tania Putri',
        ], $overrides);
    }

    public function test_a_new_customer_gets_a_session_and_can_log_in_again(): void
    {
        $response = $this->register()->assertOk()
            ->assertJsonPath('data.user.email', 'tania@mail.com')->assertJsonPath('data.user.role', 'customer')
            ->assertJsonPath('data.user.providerId', null);
        $this->withToken($response->json('data.token'))->getJson('/api/v1/equipment')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/login', ['email' => 'tania@mail.com', 'password' => 'rahasia123'])->assertOk();
        $this->assertNotSame('rahasia123', User::where('email', 'tania@mail.com')->value('password'));
        $this->assertSame('Penyewa', AuditLog::where('action', Audit::REGISTER)->value('detail'));
    }

    public function test_a_new_provider_gets_a_store_that_waits_for_the_admin(): void
    {
        $response = $this->register($this->store())->assertOk()->assertJsonPath('data.user.role', 'provider');
        $store = Provider::findOrFail($response->json('data.user.providerId'));
        $this->assertSame(['Bromo Gear', 'pending', 'Malang'], [$store->business_name, $store->status, $store->city]);
        $this->assertSame($response->json('data.user.id'), $store->owner_id);

        // Admin melihat toko baru itu di daftarnya, masih menunggu verifikasi.
        $listed = collect($this->as('admin')->getJson('/api/v1/providers')->json('data'))->firstWhere('id', $store->id);
        $this->assertSame('pending', $listed['status']);
        $this->assertSame('Penyedia: Bromo Gear', AuditLog::where('action', Audit::REGISTER)->value('detail'));
    }

    public function test_a_provider_without_store_data_is_refused(): void
    {
        $response = $this->register($this->store(['businessName' => '']));
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertSame('Lengkapi data toko.', $response->json('error.message'));
        $this->assertNull(User::where('email', 'tania@mail.com')->first());
    }

    public function test_an_empty_form_gets_one_message_not_one_per_field(): void
    {
        $response = $this->postJson('/api/v1/auth/register', []);
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertSame('Lengkapi semua isian.', $response->json('error.message'));
    }

    public function test_an_email_that_is_already_used_is_refused(): void
    {
        $response = $this->register(['email' => 'BUDI@rentgear.id']);
        $this->assertApiError($response, 'VALIDATION', 422);
        $this->assertSame('Email sudah terdaftar. Silakan masuk.', $response->json('error.message'));
    }

    public function test_nobody_can_register_as_admin(): void
    {
        $this->assertApiError($this->register(['role' => 'admin']), 'VALIDATION', 422);
        $this->assertSame(1, User::where('role', 'admin')->count());
    }

    public function test_a_short_password_or_a_bad_phone_number_is_refused(): void
    {
        $short = $this->register(['password' => '1234567']);
        $this->assertSame('Password minimal 8 karakter.', $short->json('error.message'));
        $phone = $this->register(['phone' => '0812-abc']);
        $this->assertSame('Nomor HP tidak benar.', $phone->json('error.message'));
        $this->assertSame(0, User::where('email', 'tania@mail.com')->count());
    }
}
