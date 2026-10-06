<?php

namespace App\Services;

use App\Mail\PasswordResetCode;
use App\Models\User;
use App\Support\ApiException;
use App\Support\Audit;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;
use Throwable;

/** Lupa password: kode 6 angka dikirim ke email pemilik akun, lalu ditukar dengan password baru. */
class PasswordResetService
{
    public const VALID_MINUTES = 15;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_SECONDS = 60;

    private const TABLE = 'password_reset_tokens';

    /**
     * Email yang tidak terdaftar dijawab sama dengan yang terdaftar, supaya rute ini tidak bisa dipakai untuk
     * mencari tahu siapa yang punya akun. Admin tidak dikirimi kode: passwordnya hanya diganti di server.
     */
    public function sendCode(string $email): void
    {
        $limit = 'reset-code:'.$email;
        if (RateLimiter::tooManyAttempts($limit, 1)) {
            throw new ApiException('TOO_MANY_REQUESTS', 'Kode baru saja diminta. Coba lagi dalam '.RateLimiter::availableIn($limit).' detik.');
        }
        RateLimiter::hit($limit, self::RESEND_SECONDS);

        $user = User::where('email', $email)->first();
        if ($user === null || $user->isAdmin()) {
            return;
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        // Yang disimpan hanya hash kode, sama seperti password.
        DB::table(self::TABLE)->updateOrInsert(
            ['email' => $email],
            ['token' => Hash::make($code), 'attempts' => 0, 'created_at' => now()],
        );
        try {
            Mail::to($email)->send(new PasswordResetCode($user->name, $code, self::VALID_MINUTES));
        } catch (Throwable $e) {
            report($e);
            DB::table(self::TABLE)->where('email', $email)->delete();
            RateLimiter::clear($limit);
            throw new ApiException('MAIL_UNAVAILABLE', 'Email belum bisa dikirim. Coba lagi nanti.');
        }
        Audit::record($user, Audit::PASSWORD_RESET_REQUESTED);
    }

    /** Menukar kode dengan password baru. Semua sesi lama akun itu berakhir. */
    public function reset(string $email, string $code, string $password): User
    {
        $codes = DB::table(self::TABLE)->where('email', $email);
        // Tebakan dihitung sebelum kode diperiksa, sehingga permintaan yang datang bersamaan tidak lolos dari batas.
        $codes->increment('attempts');
        $row = $codes->first();
        $user = User::where('email', $email)->first();

        $usable = $row !== null && $user !== null
            && $row->attempts <= self::MAX_ATTEMPTS
            && Carbon::parse($row->created_at)->addMinutes(self::VALID_MINUTES)->isFuture();
        if (! $usable) {
            $codes->delete();
        }
        if (! $usable || ! Hash::check($code, $row->token)) {
            throw new ApiException('RESET_CODE_INVALID', 'Kode salah atau sudah kedaluwarsa. Periksa lagi, atau minta kode baru.');
        }

        DB::transaction(function () use ($user, $password, $codes) {
            $user->update(['password' => $password]);
            $user->tokens()->delete();
            $codes->delete();
        });
        Audit::record($user, Audit::PASSWORD_RESET);

        return $user;
    }
}
