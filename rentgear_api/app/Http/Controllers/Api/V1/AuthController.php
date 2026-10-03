<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\User;
use App\Services\GoogleTokenVerifier;
use App\Support\ApiException;
use App\Support\ApiResponse;
use App\Support\Audit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => 'required|string', 'password' => 'required|string']);
        $email = strtolower(trim($data['email']));
        $user = User::where('email', $email)->first();
        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            Audit::record(null, Audit::LOGIN_FAILED, $email, anonymous: 'Tidak dikenal');
            throw new ApiException('AUTH_FAILED', 'Email atau password salah.');
        }
        Audit::record($user, Audit::LOGIN);

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
