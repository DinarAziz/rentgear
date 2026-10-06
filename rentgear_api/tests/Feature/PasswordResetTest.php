<?php

namespace Tests\Feature;

use App\Mail\PasswordResetCode;
use App\Models\AuditLog;
use App\Models\User;
use App\Services\PasswordResetService;
use App\Support\Audit;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use RuntimeException;
use Tests\ApiTestCase;

class PasswordResetTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
    }

    /** Meminta kode untuk [email] dan mengembalikan kode yang ada di emailnya. */
    private function requestCode(string $email = 'budi@rentgear.id'): string
    {
        $this->postJson('/api/v1/auth/forgot-password', ['email' => $email])->assertOk();
        $code = null;
        Mail::assertSent(PasswordResetCode::class, function (PasswordResetCode $mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    private function reset(string $code, array $overrides = [])
    {
        return $this->postJson('/api/v1/auth/reset-password', array_replace([
            'email' => 'budi@rentgear.id', 'code' => $code, 'password' => 'rahasiabaru1',
        ], $overrides));
    }

    private function login(string $password)
    {
        $this->app['auth']->forgetGuards();

        return $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => $password]);
    }

    public function test_the_code_from_the_email_sets_a_new_password_and_opens_a_session(): void
    {
        $old = $this->login('password')->json('data.token');

        $code = $this->requestCode(' Budi@RentGear.id ');
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);
        Mail::assertSent(PasswordResetCode::class, fn (PasswordResetCode $mail) => $mail->hasTo('budi@rentgear.id'));
        // Kode tidak disimpan apa adanya.
        $this->assertNotSame($code, DB::table('password_reset_tokens')->value('token'));

        $response = $this->reset(substr($code, 0, 3).' '.substr($code, 3))->assertOk()->assertJsonPath('data.user.id', 'u-budi');
        $this->withToken($response->json('data.token'))->getJson('/api/v1/auth/me')->assertOk();

        $this->assertApiError($this->login('password'), 'AUTH_FAILED', 401);
        $this->login('rahasiabaru1')->assertOk();
        // Sesi di perangkat lain ikut berakhir.
        $this->app['auth']->forgetGuards();
        $this->withToken($old)->getJson('/api/v1/auth/me')->assertStatus(401);
        $this->assertSame(
            [Audit::PASSWORD_RESET_REQUESTED, Audit::PASSWORD_RESET],
            AuditLog::whereIn('action', [Audit::PASSWORD_RESET_REQUESTED, Audit::PASSWORD_RESET])->orderBy('id')->pluck('action')->all(),
        );
    }

    public function test_a_code_works_only_once(): void
    {
        $code = $this->requestCode();
        $this->reset($code)->assertOk();
        $this->assertApiError($this->reset($code, ['password' => 'lainlagi123']), 'RESET_CODE_INVALID', 422);
        $this->login('rahasiabaru1')->assertOk();
    }

    public function test_an_unknown_email_and_the_admin_get_the_same_answer_but_no_email(): void
    {
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'tidakada@mail.com'])->assertOk();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'admin@rentgear.id'])->assertOk();
        Mail::assertNothingSent();
        $this->assertSame(0, DB::table('password_reset_tokens')->count());
    }

    public function test_a_wrong_code_is_refused_and_five_wrong_guesses_cancel_the_code(): void
    {
        $code = $this->requestCode();
        $wrong = $code === '000000' ? '000001' : '000000';
        for ($i = 0; $i < PasswordResetService::MAX_ATTEMPTS; $i++) {
            $this->assertApiError($this->reset($wrong), 'RESET_CODE_INVALID', 422);
        }
        $this->assertApiError($this->reset($code), 'RESET_CODE_INVALID', 422);
        $this->login('password')->assertOk();
    }

    public function test_a_code_expires_after_fifteen_minutes(): void
    {
        $code = $this->requestCode();
        $this->travel(PasswordResetService::VALID_MINUTES + 1)->minutes();
        $this->assertApiError($this->reset($code), 'RESET_CODE_INVALID', 422);
    }

    public function test_a_second_request_within_a_minute_is_refused_and_a_later_one_replaces_the_code(): void
    {
        $first = $this->requestCode();
        $this->assertApiError($this->postJson('/api/v1/auth/forgot-password', ['email' => 'budi@rentgear.id']), 'TOO_MANY_REQUESTS', 429);
        Mail::assertSentCount(1);

        $this->travel(PasswordResetService::RESEND_SECONDS + 1)->seconds();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'budi@rentgear.id'])->assertOk();
        Mail::assertSentCount(2);
        $codes = [];
        Mail::assertSent(PasswordResetCode::class, function (PasswordResetCode $mail) use (&$codes) {
            $codes[] = $mail->code;

            return true;
        });
        if ($codes[1] !== $first) {
            $this->assertApiError($this->reset($first), 'RESET_CODE_INVALID', 422);
        }
        $this->reset($codes[1])->assertOk();
    }

    public function test_a_short_new_password_is_refused_and_keeps_the_code_usable(): void
    {
        $code = $this->requestCode();
        $short = $this->reset($code, ['password' => '1234567']);
        $this->assertApiError($short, 'VALIDATION', 422);
        $this->assertSame('Password minimal 8 karakter.', $short->json('error.message'));
        $this->reset($code)->assertOk();
    }

    public function test_a_mail_server_that_is_down_is_reported_and_leaves_no_code(): void
    {
        Mail::shouldReceive('to->send')->andThrow(new RuntimeException('smtp mati'));

        $this->assertApiError($this->postJson('/api/v1/auth/forgot-password', ['email' => 'budi@rentgear.id']), 'MAIL_UNAVAILABLE', 503);
        $this->assertSame(0, DB::table('password_reset_tokens')->count());
        $this->assertSame(0, AuditLog::where('action', Audit::PASSWORD_RESET_REQUESTED)->count());
    }

    public function test_the_mail_check_command_warns_while_no_real_sender_is_set(): void
    {
        $this->artisan('rentgear:mail-test', ['email' => 'budi@rentgear.id'])
            ->expectsOutputToContain('email tidak dikirim ke mana pun')->assertSuccessful();

        Mail::shouldReceive('raw')->andThrow(new RuntimeException('smtp mati'));
        $this->artisan('rentgear:mail-test', ['email' => 'budi@rentgear.id'])
            ->expectsOutputToContain('smtp mati')->assertFailed();
    }

    public function test_an_account_made_with_google_can_set_a_password_this_way(): void
    {
        User::where('email', 'budi@rentgear.id')->update(['google_id' => 'g-123']);
        $this->reset($this->requestCode())->assertOk();
        $this->login('rahasiabaru1')->assertOk();
    }
}
