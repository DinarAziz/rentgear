<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\Provider;
use App\Models\User;
use App\Services\GoogleTokenVerifier;
use App\Services\PasswordResetService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use App\Support\Audit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    /** Setelah 5 kali salah password, akun itu terkunci 15 menit dari alamat IP yang sama. */
    private const MAX_LOGIN_FAILURES = 5;

    private const LOGIN_LOCK_SECONDS = 900;

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => 'required|string', 'password' => 'required|string']);
        $email = strtolower(trim($data['email']));
        // Batas per akun dan alamat IP, di samping batas per IP pada rute: password satu akun tidak bisa ditebak terus.
        $limit = 'login:'.$email.'|'.$request->ip();
        if (RateLimiter::tooManyAttempts($limit, self::MAX_LOGIN_FAILURES)) {
            $minutes = (int) ceil(RateLimiter::availableIn($limit) / 60);
            throw new ApiException('TOO_MANY_REQUESTS', "Terlalu banyak percobaan masuk. Coba lagi dalam $minutes menit, atau pakai \"Lupa password?\".");
        }
        $user = User::where('email', $email)->first();
        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            RateLimiter::hit($limit, self::LOGIN_LOCK_SECONDS);
            Audit::record(null, Audit::LOGIN_FAILED, $email, anonymous: 'Tidak dikenal');
            throw new ApiException('AUTH_FAILED', 'Email atau password salah.');
        }
        RateLimiter::clear($limit);
        Audit::record($user, Audit::LOGIN);

        return $this->session($user);
    }

    /** Titik awal toko baru di peta (Alun-alun Malang). Penyedia memindahkannya dari menu Profil. */
    private const DEFAULT_LOCATION = ['latitude' => -7.9826, 'longitude' => 112.6308];

    private const REGISTER_MESSAGES = [
        'required' => 'Lengkapi semua isian.',
        'required_if' => 'Lengkapi data toko.',
        'max' => 'Salah satu isian terlalu panjang.',
        'role.in' => 'Pilih daftar sebagai penyewa atau penyedia.',
        'email.email' => 'Format email tidak benar.',
        'email.unique' => 'Email sudah terdaftar. Silakan masuk.',
        'password.min' => 'Password minimal 8 karakter.',
        'phone.regex' => 'Nomor HP tidak benar.',
    ];

    /**
     * Daftar dengan email dan password. Penyewa langsung bisa menyewa. Penyedia mendapat toko berstatus menunggu
     * verifikasi admin, sehingga alatnya belum tampil di katalog. Akun admin tidak bisa dibuat dari sini.
     */
    public function register(Request $request): JsonResponse
    {
        $request->merge(['email' => strtolower(trim((string) $request->input('email')))]);
        $data = $request->validate([
            'role' => ['required', Rule::in([User::CUSTOMER, User::PROVIDER])],
            'name' => 'required|string|max:100',
            'email' => 'required|email|max:150|unique:users,email',
            'password' => 'required|string|min:8|max:72',
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{9,15}$/'],
            'city' => 'required|string|max:60',
            'businessName' => 'required_if:role,provider|nullable|string|max:100',
            'address' => 'required_if:role,provider|nullable|string|max:200',
            'bankAccount' => 'required_if:role,provider|nullable|string|max:100',
        ], self::REGISTER_MESSAGES);

        $user = DB::transaction(function () use ($data) {
            $user = User::create([
                'id' => 'u-'.strtolower((string) Str::ulid()),
                'name' => trim($data['name']), 'email' => $data['email'], 'password' => $data['password'],
                'phone' => $data['phone'], 'city' => trim($data['city']), 'role' => $data['role'],
            ]);
            if ($user->isProvider()) {
                $provider = Provider::create([
                    'id' => 'p-'.strtolower((string) Str::ulid()), 'owner_id' => $user->id,
                    'business_name' => trim($data['businessName']), 'city' => $user->city,
                    'address' => trim($data['address']), 'bank_account' => trim($data['bankAccount']),
                    'status' => Provider::PENDING, 'accepted_types' => ['ktp'],
                    ...self::DEFAULT_LOCATION,
                ]);
                $user->update(['provider_id' => $provider->id]);
            }

            return $user;
        });
        Audit::record($user, Audit::REGISTER, detail: $user->isProvider() ? 'Penyedia: '.$user->provider->business_name : 'Penyewa');

        return $this->session($user);
    }

    /**
     * Masuk atau daftar dengan akun Google. Akun baru selalu menjadi penyewa. Akun lama dikenali dari emailnya,
     * kecuali admin: admin hanya boleh masuk dengan password.
     */
    public function google(Request $request, GoogleTokenVerifier $verifier): JsonResponse
    {
        $data = $request->validate(['idToken' => 'required|string']);
        $google = $verifier->verify($data['idToken']);

        $user = User::where('google_id', $google['sub'])->first() ?? User::where('email', $google['email'])->first();
        if ($user?->isAdmin()) {
            Audit::record(null, Audit::LOGIN_FAILED, $google['email'], 'Akun admin mencoba masuk dengan Google.', anonymous: 'Tidak dikenal');
            throw new ApiException('FORBIDDEN', 'Akun admin hanya bisa masuk dengan password.');
        }
        if ($user === null) {
            $user = User::create([
                'id' => 'u-'.strtolower((string) Str::ulid()),
                'name' => $google['name'], 'email' => $google['email'], 'google_id' => $google['sub'],
                // Akun Google tidak punya password; nilai acak ini tidak diketahui siapa pun.
                'password' => Str::random(40),
                'phone' => '', 'city' => '', 'role' => User::CUSTOMER,
            ]);
            Audit::record($user, Audit::REGISTER_GOOGLE);
        } else {
            $user->update(['google_id' => $google['sub']]);
            Audit::record($user, Audit::LOGIN_GOOGLE);
        }

        return $this->session($user);
    }

    /** Mengirim kode ganti password ke email. Jawabannya sama untuk email yang terdaftar maupun tidak. */
    public function forgotPassword(Request $request, PasswordResetService $resets): JsonResponse
    {
        $data = $request->validate(['email' => 'required|string|max:150'], ['required' => 'Isi email akun Anda.']);
        $resets->sendCode(strtolower(trim($data['email'])));

        return ApiResponse::ok();
    }

    /** Menukar kode dari email dengan password baru, lalu langsung masuk. */
    public function resetPassword(Request $request, PasswordResetService $resets): JsonResponse
    {
        $data = $request->validate([
            'email' => 'required|string|max:150',
            'code' => 'required|string|max:20',
            'password' => 'required|string|min:8|max:72',
        ], ['required' => 'Lengkapi semua isian.', 'password.min' => 'Password minimal 8 karakter.']);

        return $this->session($resets->reset(
            strtolower(trim($data['email'])), preg_replace('/\s+/', '', $data['code']), $data['password'],
        ));
    }

    private function session(User $user): JsonResponse
    {
        return ApiResponse::ok([
            'token' => $user->createToken('app')->plainTextToken,
            'user' => Present::user($user),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return ApiResponse::ok(Present::user($request->user()));
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return ApiResponse::ok();
    }
}
