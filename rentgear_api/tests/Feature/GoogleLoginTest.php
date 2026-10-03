<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Tests\ApiTestCase;

class GoogleLoginTest extends ApiTestCase
{
    private const CLIENT = 'rentgear-web.apps.googleusercontent.com';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_ids' => [self::CLIENT]]);
    }

    /** Jawaban tokeninfo dari Google untuk satu ID token. */
    private function google(array $claims = []): void
    {
        Http::fake(['oauth2.googleapis.com/*' => Http::response(array_replace([
            'aud' => self::CLIENT, 'iss' => 'https://accounts.google.com', 'exp' => (string) (time() + 600),
            'sub' => '1122334455', 'email' => 'Tania@Gmail.com', 'email_verified' => 'true', 'name' => 'Tania Putri',
        ], $claims))]);
    }

    public function test_a_new_google_account_becomes_a_customer(): void
    {
        $this->google();
        $response = $this->postJson('/api/v1/auth/google', ['idToken' => 'token'])->assertOk()
            ->assertJsonPath('data.user.email', 'tania@gmail.com')->assertJsonPath('data.user.name', 'Tania Putri')
            ->assertJsonPath('data.user.role', 'customer');

        $this->withToken($response->json('data.token'))->getJson('/api/v1/auth/me')->assertJsonPath('data.email', 'tania@gmail.com');
        $this->assertSame('1122334455', User::where('email', 'tania@gmail.com')->value('google_id'));

        // Masuk lagi memakai akun yang sama, tidak membuat akun kedua.
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/auth/google', ['idToken' => 'token'])->assertOk();
        $this->assertSame(1, User::where('email', 'tania@gmail.com')->count());
    }

    public function test_an_existing_account_is_matched_by_email_and_keeps_its_role(): void
    {
        $this->google(['email' => 'sari@rentgear.id', 'sub' => '99']);
        $this->postJson('/api/v1/auth/google', ['idToken' => 'token'])->assertOk()
            ->assertJsonPath('data.user.id', 'u-sari')->assertJsonPath('data.user.providerId', 'p-arjuna');
        $this->assertSame('99', User::find('u-sari')->google_id);
    }

    public function test_admin_cannot_sign_in_with_google(): void
    {
        $this->google(['email' => 'admin@rentgear.id']);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'token']), 'FORBIDDEN', 403);
    }

    public function test_tokens_for_another_app_or_unverified_emails_are_refused(): void
    {
        $this->google(['aud' => 'aplikasi-lain.apps.googleusercontent.com']);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'token']), 'AUTH_FAILED', 401);

        $this->google(['email_verified' => 'false']);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'token']), 'AUTH_FAILED', 401);

        $this->google(['exp' => (string) (time() - 5)]);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'token']), 'AUTH_FAILED', 401);

        Http::fake(['oauth2.googleapis.com/*' => Http::response(['error' => 'invalid_token'], 400)]);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'palsu']), 'AUTH_FAILED', 401);
        $this->assertSame(0, User::where('email', 'tania@gmail.com')->count());
    }

    public function test_google_login_is_off_until_a_client_id_is_set(): void
    {
        config(['services.google.client_ids' => []]);
        $this->assertApiError($this->postJson('/api/v1/auth/google', ['idToken' => 'token']), 'GOOGLE_NOT_CONFIGURED', 503);
    }
}
