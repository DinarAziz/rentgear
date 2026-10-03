<?php

namespace App\Services;

use App\Support\ApiException;
use Illuminate\Http\Client\ConnectionException;
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
     * @param  list<array{label: string, mime: string, data: string}>  $images  foto (base64), tiap foto diberi label
     * @return array<string, mixed>
     */
    public function json(string $prompt, array $schema, array $images = []): array
    {
        $key = config('services.gemini.api_key');
        if (empty($key)) {
            throw new ApiException('AI_UNAVAILABLE', 'Fitur AI belum diatur di server.');
        }

        try {
            $model = config('services.gemini.model');
            // Kunci dikirim lewat header, bukan di URL, supaya tidak ikut tercatat di log.
            // Sambungan yang macet dicoba sekali lagi; dua kali 9 detik masih di bawah batas tunggu aplikasi
            // (20 detik). Jawaban galat dari Gemini (mis. kuota habis) tidak diulang, supaya kuota tidak makin habis.
            $response = Http::withHeaders(['x-goog-api-key' => $key])->timeout(9)
                ->retry(2, 0, fn (Throwable $e) => $e instanceof ConnectionException, throw: false)
                ->post("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent", [
                    'contents' => [['parts' => [
                        ['text' => $prompt],
                        ...collect($images)->flatMap(fn (array $i) => [
                            ['text' => $i['label']],
                            ['inline_data' => ['mime_type' => $i['mime'], 'data' => $i['data']]],
                        ])->all(),
                    ]]],
                    'generationConfig' => [
                        'responseMimeType' => 'application/json', 'responseSchema' => $schema, 'temperature' => 0.2,
                        // Tanpa tahap "berpikir": jawaban datang dalam beberapa detik, cukup untuk saran singkat.
                        'thinkingConfig' => ['thinkingBudget' => 0],
                    ],
                ]);
            $text = $response->successful() ? $response->json('candidates.0.content.parts.0.text') : null;
            $data = is_string($text) ? json_decode($text, true) : null;
        } catch (Throwable $e) {
            // Dicatat untuk pengembang. Pesannya tidak memuat kunci, karena kunci ada di header.
            logger()->warning('Gemini gagal: '.$e->getMessage());
            $data = null;
        }
        if (isset($response) && ! $response->successful()) {
            logger()->warning('Gemini menjawab '.$response->status().': '.mb_substr($response->body(), 0, 300));
            if ($response->status() === 429) {
                throw new ApiException('AI_UNAVAILABLE', 'Kuota AI sedang habis. Coba lagi beberapa menit lagi.');
            }
        }
        if (! is_array($data)) {
            throw new ApiException('AI_UNAVAILABLE', 'AI sedang tidak bisa dihubungi. Coba lagi nanti.');
        }

        return $data;
    }
}
