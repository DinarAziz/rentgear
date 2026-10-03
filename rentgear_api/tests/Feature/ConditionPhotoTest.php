<?php

namespace Tests\Feature;

use App\Models\ConditionPhoto;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\ApiTestCase;

/** r-3: carrier Rina di Arjuna Outdoor (Sari), sudah dibayar. r-4: tenda Budi di Semeru Camp Rent (Dewi), sedang disewa. */
class ConditionPhotoTest extends ApiTestCase
{
    private function add(string $rental, string $phase)
    {
        return $this->post("/api/v1/rentals/$rental/condition-photos", ['phase' => $phase, 'photo' => $this->photo()],
            ['Accept' => 'application/json']);
    }

    public function test_only_the_store_adds_photos_and_only_at_the_right_time(): void
    {
        $this->as('rina');
        $this->assertApiError($this->add('r-3', 'handover'), 'FORBIDDEN', 403);
        $this->as('dewi');
        $this->assertApiError($this->add('r-3', 'handover'), 'FORBIDDEN', 403);

        $this->as('sari');
        $this->add('r-3', 'handover')->assertOk()->assertJsonPath('data.conditionPhotos.0.phase', 'handover');
        // Alat belum kembali, jadi belum ada foto pengembalian.
        $this->assertApiError($this->add('r-3', 'return'), 'INVALID_STATE', 409);
        $this->assertApiError($this->add('r-3', 'lain'), 'VALIDATION', 422);

        $this->postJson('/api/v1/rentals/r-3/handover')->assertOk();
        $this->postJson('/api/v1/rentals/r-3/return', ['condition' => 'good'])->assertOk();
        $this->assertApiError($this->add('r-3', 'handover'), 'INVALID_STATE', 409);
        $this->add('r-3', 'return')->assertOk()->assertJsonCount(2, 'data.conditionPhotos');
    }

    public function test_at_most_four_photos_per_phase_and_no_way_to_remove_them(): void
    {
        $this->as('dewi');
        foreach (range(1, 4) as $_) {
            $this->add('r-4', 'handover')->assertOk();
        }
        $this->assertApiError($this->add('r-4', 'handover'), 'VALIDATION', 422);
        $this->assertSame(4, ConditionPhoto::where('rental_id', 'r-4')->count());

        $id = ConditionPhoto::firstOrFail()->id;
        $this->deleteJson("/api/v1/files/condition/$id")->assertStatus(405);
        $this->deleteJson('/api/v1/rentals/r-4/condition-photos')->assertStatus(405);
    }

    public function test_photos_are_private_to_the_rental_parties(): void
    {
        $this->as('dewi');
        $this->add('r-4', 'handover')->assertOk();
        $photo = ConditionPhoto::firstOrFail();
        Storage::disk('local')->assertExists($photo->path);

        $this->get("/api/v1/files/condition/{$photo->id}")->assertOk();
        $this->as('budi')->get("/api/v1/files/condition/{$photo->id}")->assertOk();
        $this->as('admin')->get("/api/v1/files/condition/{$photo->id}")->assertOk();
        $this->assertApiError($this->as('rina')->getJson("/api/v1/files/condition/{$photo->id}"), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('sari')->getJson("/api/v1/files/condition/{$photo->id}"), 'FORBIDDEN', 403);
    }

    public function test_the_fine_opinion_compares_the_photos(): void
    {
        config(['services.gemini.api_key' => 'kunci-uji']);
        $this->as('dewi');
        $this->add('r-4', 'handover')->assertOk();
        $this->postJson('/api/v1/rentals/r-4/return', ['condition' => 'majorDamage', 'damageFee' => 100000, 'damageNote' => 'Robek'])->assertOk();
        $this->add('r-4', 'return')->assertOk();

        Http::fake(['generativelanguage.googleapis.com/*' => Http::response(['candidates' => [['content' => ['parts' => [['text' => json_encode([
            'penilaian' => 'wajar', 'denda_saran' => 100000, 'penjelasan' => 'Sebanding.', 'temuan_foto' => ' Robekan baru di flysheet. ',
        ])]]]]]])]);

        $opinion = $this->as('admin')->postJson('/api/v1/ai/rentals/r-4/fine-opinion')->assertOk()->json('data');
        $this->assertSame('Robekan baru di flysheet.', $opinion['photoFinding']);
        $this->assertSame([1, 1], [$opinion['photosBefore'], $opinion['photosAfter']]);

        Http::assertSent(function (Request $request) {
            $parts = $request['contents'][0]['parts'];

            return count($parts) === 5 && str_contains($parts[1]['text'], 'saat diserahkan')
                && str_contains($parts[3]['text'], 'saat kembali') && $parts[2]['inline_data']['data'] !== '';
        });
    }
}
