<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\ApiTestCase;

class AiTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config(['services.gemini.api_key' => 'kunci-uji']);
    }

    /** Jawaban Gemini berisi satu teks JSON. */
    private function gemini(array $json): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::response([
            'candidates' => [['content' => ['parts' => [['text' => json_encode($json)]]]]],
        ])]);
    }

    public function test_recommendation_keeps_only_real_gear_and_prices_it_on_the_server(): void
    {
        $this->gemini([
            'ringkasan' => 'Paket untuk 4 orang.',
            'alat' => [
                ['id' => 'e-dome4', 'jumlah' => 99, 'alasan' => 'Muat 4 orang.'],
                ['id' => 'e-karangan', 'jumlah' => 1, 'alasan' => 'Tidak ada di katalog.'],
                ['id' => 'e-kompor', 'jumlah' => 1, 'alasan' => 'Untuk memasak.'],
            ],
            'tips' => ['Bawa jas hujan.'],
        ]);

        $data = $this->as('budi')->postJson('/api/v1/ai/recommend', ['trip' => 'Semeru, musim hujan', 'people' => 4, 'days' => 2])
            ->assertOk()->json('data');

        $this->assertSame(['e-dome4', 'e-kompor'], array_column($data['items'], 'equipmentId'));
        // Jumlah dibatasi stok (3 tenda), biaya dihitung server: 45.000 x 3 x 2 hari + 20.000 x 1 x 2 hari.
        $this->assertSame(3, $data['items'][0]['qty']);
        $this->assertEquals(270000, $data['items'][0]['rentCost']);
        $this->assertEquals(310000, $data['rentTotal']);
        $this->assertEquals(350000, $data['depositTotal']);
        $this->assertSame(['Bawa jas hujan.'], $data['tips']);

        // Kunci ada di header, tidak di URL, dan katalog hanya berisi alat toko terverifikasi.
        Http::assertSent(function (Request $request) {
            $prompt = $request['contents'][0]['parts'][0]['text'];

            return $request->hasHeader('x-goog-api-key', 'kunci-uji') && ! str_contains($request->url(), 'kunci-uji')
                && str_contains($prompt, 'e-dome4') && ! str_contains($prompt, 'Puncak Outdoor');
        });
    }

    public function test_risk_and_fine_opinion_are_for_admin_and_send_no_identity(): void
    {
        $this->gemini(['tingkat' => 'sedang', 'ringkasan' => 'Satu kali terlambat.', 'faktor' => ['Terlambat sekali.']]);
        $this->assertApiError($this->as('sari')->postJson('/api/v1/ai/customers/u-budi/risk'), 'FORBIDDEN', 403);

        $risk = $this->as('admin')->postJson('/api/v1/ai/customers/u-budi/risk')->assertOk()->json('data');
        $this->assertSame('sedang', $risk['level']);
        $this->assertSame(['Terlambat sekali.'], $risk['factors']);
        Http::assertSent(function (Request $request) {
            $prompt = $request['contents'][0]['parts'][0]['text'];

            return ! str_contains($prompt, 'Budi') && ! str_contains($prompt, 'budi@rentgear.id');
        });
        $this->assertSame('ai_customer_risk', AuditLog::latest('id')->value('action'));
    }

    public function test_fine_opinion_never_suggests_more_than_the_deposit(): void
    {
        // r-4: tenda ultralight Budi, deposit 150.000, diterima kembali rusak berat dengan denda 100.000.
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return', ['condition' => 'majorDamage', 'damageFee' => 100000, 'damageNote' => 'Robek'])
            ->assertOk();
        $this->gemini(['penilaian' => 'terlalu_tinggi', 'denda_saran' => 9000000, 'penjelasan' => 'Catatan terlalu singkat.']);

        $this->assertApiError($this->as('budi')->postJson('/api/v1/ai/rentals/r-4/fine-opinion'), 'FORBIDDEN', 403);
        $opinion = $this->as('admin')->postJson('/api/v1/ai/rentals/r-4/fine-opinion')->assertOk()->json('data');
        $this->assertSame('terlalu_tinggi', $opinion['verdict']);
        $this->assertEquals(150000, $opinion['suggestedFee']);
        $this->assertEquals(100000, $opinion['proposedFee']);

        // Denda yang masih ditinjau belum dihitung sebagai pelanggaran di data yang dikirim ke AI.
        $this->gemini(['tingkat' => 'rendah', 'ringkasan' => '-', 'faktor' => []]);
        $this->postJson('/api/v1/ai/customers/u-budi/risk')->assertOk();
        Http::assertSent(function (Request $request) {
            $prompt = $request['contents'][0]['parts'][0]['text'];

            return str_contains($prompt, '"denda_kerusakan_masih_ditinjau": true') && ! str_contains($prompt, '100000')
                && str_contains($prompt, '"pelanggaran_lagi_sebelum_blacklist_otomatis"');
        });

        // Pendapat AI tidak mengubah transaksi.
        $this->assertEquals(100000, $this->getJson('/api/v1/rentals/r-4')->json('data.damageFee'));
        $this->assertApiError($this->postJson('/api/v1/ai/rentals/r-1/fine-opinion'), 'INVALID_STATE', 409);
    }

    public function test_the_app_keeps_working_when_ai_is_down_or_not_configured(): void
    {
        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(['error' => 'quota'], 429)]);
        $response = $this->as('budi')->postJson('/api/v1/ai/recommend', ['trip' => 'Semeru', 'people' => 2, 'days' => 2]);
        $this->assertApiError($response, 'AI_UNAVAILABLE', 503);
        $this->assertSame('Kuota AI sedang habis. Coba lagi beberapa menit lagi.', $response->json('error.message'));
        // Kuota habis tidak dicoba ulang.
        Http::assertSentCount(1);

        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(['candidates' => [['content' => ['parts' => [['text' => 'bukan json']]]]]])]);
        $this->assertApiError($this->postJson('/api/v1/ai/recommend', ['trip' => 'Semeru', 'people' => 2, 'days' => 2]), 'AI_UNAVAILABLE', 503);

        config(['services.gemini.api_key' => null]);
        $this->assertApiError($this->postJson('/api/v1/ai/recommend', ['trip' => 'Semeru', 'people' => 2, 'days' => 2]), 'AI_UNAVAILABLE', 503);
        // Katalog biasa tetap jalan.
        $this->getJson('/api/v1/equipment')->assertOk();
    }
}
