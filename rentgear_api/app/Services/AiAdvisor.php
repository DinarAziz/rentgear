<?php

namespace App\Services;

use App\Models\Equipment;
use App\Models\Rental;
use App\Models\User;

/**
 * Tiga saran AI: paket alat untuk penyewa, pendapat atas denda kerusakan, dan tingkat risiko penyewa untuk admin.
 *
 * AI hanya memberi saran. Uang (harga, deposit, denda) selalu dihitung atau dibatasi di sini, dan keputusan tetap
 * diambil manusia. Nama, email, nomor dokumen, dan foto penyewa tidak pernah dikirim ke Gemini.
 */
final class AiAdvisor
{
    private const STRING = ['type' => 'STRING'];

    /** Sama dengan `ReturnCondition.label` di aplikasi, supaya AI tidak menjawab dengan kode. */
    private const CONDITIONS = [
        'good' => 'baik', 'minorDamage' => 'rusak ringan', 'majorDamage' => 'rusak berat', 'lost' => 'hilang',
    ];

    public function __construct(private readonly GeminiClient $gemini, private readonly BlacklistService $blacklist) {}

    /** Paket alat untuk satu perjalanan, dipilih dari alat yang benar-benar ada di katalog. */
    public function recommend(string $trip, int $people, int $days): array
    {
        $catalog = Equipment::with('sizes', 'photos', 'provider')->where('is_active', true)
            ->whereHas('provider', fn ($q) => $q->where('status', 'verified'))->orderBy('id')->get()->keyBy('id');

        $lines = $catalog->map(fn (Equipment $e) => json_encode([
            'id' => $e->id, 'nama' => $e->name, 'kategori' => $e->category_id, 'harga_per_hari' => (float) $e->price_per_day,
            'kapasitas_orang' => $e->capacity_person, 'stok' => $this->stockOf($e),
            'toko' => $e->provider->business_name, 'kota' => $e->provider->city,
        ], JSON_UNESCAPED_UNICODE))->implode("\n");

        $answer = $this->gemini->json(<<<PROMPT
            Kamu asisten penyewaan alat hiking dan camping di Indonesia.
            Rencana penyewa: "$trip". Jumlah orang: $people. Lama sewa: $days hari.

            Pilih alat dari katalog di bawah yang paling dibutuhkan untuk rencana itu. Aturan:
            - Hanya pakai "id" yang ada di katalog. Jangan mengarang alat.
            - "jumlah" tidak boleh melebihi "stok". Untuk tenda, hitung dari "kapasitas_orang".
            - Utamakan alat dari satu toko atau satu kota bila memungkinkan, supaya mudah diambil.
            - Paling banyak 6 alat. "alasan" satu kalimat pendek dalam bahasa Indonesia.
            - "tips": paling banyak 3 saran singkat tentang perlengkapan yang tidak ada di katalog atau hal yang perlu disiapkan.
            - "ringkasan": satu atau dua kalimat.

            Katalog (satu alat per baris):
            $lines
            PROMPT, [
            'type' => 'OBJECT',
            'properties' => [
                'ringkasan' => self::STRING,
                'alat' => ['type' => 'ARRAY', 'items' => [
                    'type' => 'OBJECT',
                    'properties' => ['id' => self::STRING, 'jumlah' => ['type' => 'INTEGER'], 'alasan' => self::STRING],
                    'required' => ['id', 'jumlah', 'alasan'],
                ]],
                'tips' => ['type' => 'ARRAY', 'items' => self::STRING],
            ],
            'required' => ['ringkasan', 'alat', 'tips'],
        ]);

        // Jawaban AI diperiksa lagi: alat harus ada, jumlah dibatasi stok, dan biaya dihitung server.
        $items = collect($answer['alat'] ?? [])->filter(fn ($i) => is_array($i) && $catalog->has($i['id'] ?? ''))
            ->unique('id')->take(6)->map(function (array $i) use ($catalog, $days) {
                $e = $catalog[$i['id']];
                $qty = max(1, min((int) ($i['jumlah'] ?? 1), max(1, $this->stockOf($e))));

                return [
                    'equipmentId' => $e->id, 'name' => $e->name, 'providerName' => $e->provider->business_name,
                    'city' => $e->provider->city, 'qty' => $qty, 'reason' => (string) ($i['alasan'] ?? ''),
                    'pricePerDay' => (float) $e->price_per_day,
                    'rentCost' => (float) $e->price_per_day * $qty * $days,
                    'deposit' => (float) $e->deposit_amount * $qty,
                ];
            })->values();

        return [
            'summary' => (string) ($answer['ringkasan'] ?? ''),
            'items' => $items->all(),
            'tips' => $this->firstStrings($answer['tips'] ?? []),
            'days' => $days, 'people' => $people,
            'rentTotal' => $items->sum('rentCost'), 'depositTotal' => $items->sum('deposit'),
        ];
    }

    /** Pendapat kedua atas denda kerusakan yang diusulkan penyedia. Admin tetap yang memutuskan. */
    public function fineOpinion(Rental $r): array
    {
        $deposit = $r->depositTotal();
        $facts = json_encode([
            'alat' => $r->equipment_name, 'kategori' => $r->category_id, 'jumlah_unit' => $r->qty,
            'harga_sewa_per_hari' => (float) $r->price_per_day_snapshot, 'total_deposit' => $deposit,
            'kondisi_saat_kembali' => $this->conditionLabel($r->return_condition),
            'denda_kerusakan_diusulkan' => (float) $r->damage_fee,
            'catatan_penyedia' => $r->damage_note, 'keberatan_penyewa' => $r->review_reason,
            'denda_terlambat' => (float) $r->late_fee,
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

        $answer = $this->gemini->json(<<<PROMPT
            Kamu membantu admin marketplace sewa alat hiking menilai denda kerusakan. Aturan platform:
            denda kerusakan ditetapkan penyedia, paling tinggi sebesar total deposit, dan harus sebanding dengan
            kerusakan. Kondisi alat saat kembali: baik, rusak ringan, rusak berat, atau hilang.

            Data transaksi:
            $facts

            Nilai apakah denda yang diusulkan wajar untuk kondisi dan catatan itu. Bila catatan terlalu singkat untuk
            menilai, pilih "perlu_bukti". "denda_saran" dalam rupiah, antara 0 dan total deposit. "penjelasan" paling
            banyak tiga kalimat dalam bahasa Indonesia, tanpa menyebut dirimu sebagai AI.
            PROMPT, [
            'type' => 'OBJECT',
            'properties' => [
                'penilaian' => ['type' => 'STRING', 'enum' => ['wajar', 'terlalu_tinggi', 'terlalu_rendah', 'perlu_bukti']],
                'denda_saran' => ['type' => 'NUMBER'],
                'penjelasan' => self::STRING,
            ],
            'required' => ['penilaian', 'denda_saran', 'penjelasan'],
        ]);

        return [
            'verdict' => (string) ($answer['penilaian'] ?? 'perlu_bukti'),
            // Saran AI tidak boleh keluar dari batas yang juga berlaku untuk admin.
            'suggestedFee' => max(0.0, min((float) ($answer['denda_saran'] ?? 0), $deposit)),
            'explanation' => (string) ($answer['penjelasan'] ?? ''),
            'proposedFee' => (float) $r->damage_fee, 'depositTotal' => $deposit,
        ];
    }

    /** Tingkat risiko seorang penyewa dari riwayat sewanya, untuk membantu keputusan blacklist. */
    public function customerRisk(User $customer): array
    {
        $record = $this->blacklist->recordOf($customer);
        $history = Rental::where('customer_id', $customer->id)->orderBy('created_at')->get()->map(fn (Rental $r) => [
            'status' => $r->status, 'denda_terlambat' => (float) $r->late_fee, 'denda_kerusakan' => (float) $r->damage_fee,
            'kondisi_kembali' => $this->conditionLabel($r->return_condition),
        ])->all();
        // Tanpa nama, email, atau nomor dokumen.
        $facts = json_encode([
            'jumlah_sewa' => $record['rentalCount'], 'terlambat' => $record['lateCount'],
            'tidak_diambil' => $record['noShowCount'], 'merusak_alat' => $record['damageCount'],
            'total_denda' => $record['fineTotal'], 'sedang_blacklist' => $record['blacklist'] !== null,
            'riwayat' => $history,
        ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

        $answer = $this->gemini->json(<<<PROMPT
            Kamu membantu admin marketplace sewa alat hiking menilai risiko seorang penyewa. Platform memasukkan
            penyewa ke blacklist otomatis setelah 3 pelanggaran (terlambat, tidak mengambil alat, merusak alat).

            Riwayat penyewa (tanpa identitas):
            $facts

            Tentukan tingkat risiko: "rendah", "sedang", atau "tinggi". "ringkasan" paling banyak dua kalimat.
            "faktor": paling banyak 3 hal konkret dari riwayat yang mendasari penilaian. Bahasa Indonesia, tanpa
            menyebut dirimu sebagai AI. Jangan menyarankan hukuman; keputusan ada di admin.
            PROMPT, [
            'type' => 'OBJECT',
            'properties' => [
                'tingkat' => ['type' => 'STRING', 'enum' => ['rendah', 'sedang', 'tinggi']],
                'ringkasan' => self::STRING,
                'faktor' => ['type' => 'ARRAY', 'items' => self::STRING],
            ],
            'required' => ['tingkat', 'ringkasan', 'faktor'],
        ]);

        return [
            'level' => (string) ($answer['tingkat'] ?? 'sedang'),
            'summary' => (string) ($answer['ringkasan'] ?? ''),
            'factors' => $this->firstStrings($answer['faktor'] ?? []),
            'violations' => BlacklistService::violations($record),
        ];
    }

    private function conditionLabel(?string $condition): ?string
    {
        return self::CONDITIONS[$condition] ?? $condition;
    }

    /**
     * Paling banyak tiga butir teks dari daftar jawaban AI; isi yang bukan teks dibuang.
     *
     * @return list<string>
     */
    private function firstStrings(mixed $answers): array
    {
        return collect($answers)->filter(fn ($v) => is_string($v))->take(3)->values()->all();
    }

    private function stockOf(Equipment $e): int
    {
        return $e->hasSizes() ? (int) $e->sizes->sum('stock') : (int) $e->stock;
    }
}
