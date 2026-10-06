<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Header keamanan untuk semua jawaban API, termasuk foto yang diunggah pengguna. */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        // Browser tidak boleh menebak jenis berkas: foto unggahan tidak akan pernah dijalankan sebagai halaman atau skrip.
        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('Referrer-Policy', 'no-referrer');
        // Versi PHP tidak perlu diumumkan.
        header_remove('X-Powered-By');

        return $response;
    }
}
