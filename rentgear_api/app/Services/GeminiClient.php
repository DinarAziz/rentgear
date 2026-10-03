<?php

namespace App\Services;

use App\Support\ApiException;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Pemanggil Gemini. Kunci API hanya dibaca di sini, dari `.env` server.
 *
 * Semua kegagalan (kunci kosong, jaringan, kuota, jawaban tidak sesuai skema) menjadi `AI_UNAVAILABLE`, supaya
 * pemanggil cukup menampilkan satu pesan dan sisa aplikasi tetap jalan tanpa AI.
 */
class GeminiClient
{
    /**
     * Minta jawaban JSON yang mengikuti [schema] (format OpenAPI yang dipakai Gemini).
     *
     * @return array<string, mixed>
     */
    public function json(string $prompt, array $schema): array
    {
        $key = config('services.gemini.api_key');
        if (empty($key)) {
            throw new ApiException('AI_UNAVAILABLE', 'Fitur AI belum diatur di server.');
        }

        try {
            $model = config('services.gemini.model');
            // Kunci dikirim lewat header, bukan di URL, supaya tidak ikut tercatat di log.
            $response = Http::withHeaders(['x-goog-api-key' => $key])->timeout(15)
                ->post("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent", [
                    'contents' => [['parts' => [['text' => $prompt]]]],
                    'generationConfig' => [
                        'responseMimeType' => 'application/json', 'responseSchema' => $schema, 'temperature' => 0.2,
                        // Tanpa tahap "berpikir": jawaban datang dalam beberapa detik, cukup untuk saran singkat.
                        'thinkingConfig' => ['thinkingBudget' => 0],
                    ],
                ]);
            $text = $response->successful() ? $response->json('candidates.0.content.parts.0.text') : null;
            $data = is_string($text) ? json_decode($text, true) : null;
        } catch (Throwable) {
            $data = null;
        }
        if (! is_array($data)) {
            throw new ApiException('AI_UNAVAILABLE', 'AI sedang tidak bisa dihubungi. Coba lagi nanti.');
        }

        return $data;
    }
}
