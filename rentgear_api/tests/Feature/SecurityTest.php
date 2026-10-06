<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Equipment;
use App\Models\Provider;
use App\Support\Audit;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Tests\ApiTestCase;

class SecurityTest extends ApiTestCase
{
    private function login(string $password)
    {
        $this->app['auth']->forgetGuards();

        return $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => $password]);
    }

    public function test_five_wrong_passwords_lock_the_account_for_fifteen_minutes(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->assertApiError($this->login('salah'), 'AUTH_FAILED', 401);
        }
        // Password yang benar pun ditolak selama terkunci.
        $this->assertApiError($this->login('password'), 'TOO_MANY_REQUESTS', 429);
        // Akun lain tidak ikut terkunci.
        $this->postJson('/api/v1/auth/login', ['email' => 'sari@rentgear.id', 'password' => 'password'])->assertOk();

        $this->travel(16)->minutes();
        $this->login('password')->assertOk();
    }

    public function test_a_wrong_password_is_audited_but_not_written_to_the_error_log(): void
    {
        Log::spy();
        $this->assertApiError($this->login('salah'), 'AUTH_FAILED', 401);
        Log::shouldNotHaveReceived('error');
        $this->assertSame(1, AuditLog::where('action', Audit::LOGIN_FAILED)->count());
    }

    public function test_a_successful_login_resets_the_count_of_wrong_passwords(): void
    {
        for ($round = 0; $round < 2; $round++) {
            for ($i = 0; $i < 4; $i++) {
                $this->assertApiError($this->login('salah'), 'AUTH_FAILED', 401);
            }
            $this->login('password')->assertOk();
        }
    }

    public function test_too_many_requests_on_a_route_get_the_api_envelope(): void
    {
        for ($i = 0; $i < 20; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => "orang$i@mail.com", 'password' => 'x']);
        }
        $this->assertApiError($this->postJson('/api/v1/auth/login', ['email' => 'lain@mail.com', 'password' => 'x']), 'TOO_MANY_REQUESTS', 429);
    }

    public function test_a_login_token_stops_working_after_thirty_days(): void
    {
        $token = $this->login('password')->json('data.token');
        $this->travel(29)->days();
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();

        $this->travel(2)->days();
        $this->app['auth']->forgetGuards();
        $this->assertApiError($this->withToken($token)->getJson('/api/v1/auth/me'), 'UNAUTHENTICATED', 401);
    }

    public function test_api_answers_and_photos_carry_security_headers(): void
    {
        $response = $this->as('budi')->getJson('/api/v1/categories')->assertOk();
        $response->assertHeader('X-Content-Type-Options', 'nosniff')->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('Referrer-Policy', 'no-referrer');
        $this->postJson('/api/v1/auth/login', [])->assertHeader('X-Content-Type-Options', 'nosniff');
        // Tanpa login: jawaban 401 datang dari pemeriksa login, sebelum pengendali mana pun.
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/rentals', ['Authorization' => 'Bearer salah'])->assertStatus(401)
            ->assertHeader('X-Content-Type-Options', 'nosniff');
    }

    public function test_uploads_that_are_not_jpg_png_or_webp_are_refused(): void
    {
        // Berkas sungguhan, bukan tiruan: jenisnya dibaca dari isi, sehingga nama ".jpg" tidak menolong.
        $path = tempnam(sys_get_temp_dir(), 'rg');
        file_put_contents($path, '<html><script>alert(1)</script></html>');
        $page = new UploadedFile($path, 'foto.jpg', 'image/jpeg', null, true);
        $drawing = UploadedFile::fake()->createWithContent('foto.svg', '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
        $gif = UploadedFile::fake()->image('foto.gif');

        foreach ([$page, $drawing, $gif] as $file) {
            $response = $this->book(['guarantees' => [[
                'type' => 'ktp', 'holderName' => 'Budi Santoso', 'documentNumber' => '3573011204020001', 'photo' => $file,
            ]]], 'k-'.$file->getClientOriginalName());
            $this->assertApiError($response, 'VALIDATION', 422);
            $this->assertSame('Foto harus berupa JPG, PNG, atau WebP.', $response->json('error.message'));
        }
        $this->book()->assertOk();
    }

    public function test_a_store_that_is_not_verified_is_listed_only_for_its_owner_and_the_admin(): void
    {
        Provider::where('id', 'p-arjuna')->update(['status' => Provider::PENDING]);
        $ids = fn (string $who) => collect($this->as($who)->getJson('/api/v1/providers')->json('data'))->pluck('id');

        $this->assertNotContains('p-arjuna', $ids('budi'));
        $this->assertNotContains('p-arjuna', $ids('dewi'));
        $this->assertContains('p-arjuna', $ids('sari'));
        $this->assertContains('p-arjuna', $ids('admin'));
    }

    public function test_hidden_gear_of_a_store_is_shown_only_to_its_owner_and_the_admin(): void
    {
        Equipment::where('id', 'e-kompor')->update(['is_active' => false]);
        $ids = fn (string $who) => collect($this->as($who)->getJson('/api/v1/providers/p-arjuna/equipment')->json('data'))->pluck('id');

        $this->assertNotContains('e-kompor', $ids('budi'));
        $this->assertNotContains('e-kompor', $ids('dewi'));
        $this->assertContains('e-kompor', $ids('sari'));
        $this->assertContains('e-kompor', $ids('admin'));
    }
}
