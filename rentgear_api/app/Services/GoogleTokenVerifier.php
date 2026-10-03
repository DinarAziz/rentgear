<?php

namespace App\Services;

use App\Support\ApiException;
use Illuminate\Support\Facades\Http;

/**
 * Memeriksa ID token dari tombol "Masuk dengan Google".
 *
 * Token diperiksa oleh Google sendiri lewat endpoint tokeninfo (tanda tangan dan masa berlaku), lalu server
 * memastikan token itu memang dibuat untuk aplikasi ini (`aud`) dan emailnya sudah terverifikasi.
 */
class GoogleTokenVerifier
{
    private const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

    /** @return array{sub: string, email: string, name: string} */
    public function verify(string $idToken): array
    {
        $clientIds = config('services.google.client_ids');
        if ($clientIds === []) {
            throw new ApiException('GOOGLE_NOT_CONFIGURED', 'Login Google belum diatur di server.');
        }

        $response = Http::timeout(8)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $idToken]);
        $claims = $response->successful() ? $response->json() : null;
        $valid = is_array($claims)
            && in_array($claims['aud'] ?? null, $clientIds, true)
            && in_array($claims['iss'] ?? null, self::ISSUERS, true)
            && (int) ($claims['exp'] ?? 0) > time()
            && in_array($claims['email_verified'] ?? false, [true, 'true'], true)
            && ! empty($claims['sub']) && ! empty($claims['email']);
        if (! $valid) {
            throw new ApiException('AUTH_FAILED', 'Akun Google tidak bisa diverifikasi.');
        }

        $email = strtolower($claims['email']);

        return ['sub' => (string) $claims['sub'], 'email' => $email, 'name' => trim($claims['name'] ?? '') ?: $email];
    }
}
