<?php

namespace Tests\Feature;

use App\Mail\StoreVerificationResult;
use App\Models\AuditLog;
use App\Models\BlacklistEntry;
use App\Models\Provider;
use App\Models\User;
use App\Support\Audit;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use RuntimeException;
use Tests\ApiTestCase;

class StoreVerificationTest extends ApiTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Mail::fake();
    }

    /** Akun penyedia baru dengan toko yang belum mengirim dokumen. */
    private function newProvider(string $email = 'tania@mail.com'): User
    {
        $this->postJson('/api/v1/auth/register', [
            'role' => 'provider', 'name' => 'Tania Putri', 'email' => $email, 'password' => 'rahasia123',
            'phone' => '081298765432', 'city' => 'Malang', 'businessName' => 'Bromo Gear',
            'address' => 'Jl. Ijen No. 3, Malang', 'bankAccount' => 'BCA 1234567890 a.n. Tania Putri',
        ])->assertOk();
        $this->app['auth']->forgetGuards();

        return User::where('email', $email)->firstOrFail();
    }

    private function submit(User $owner, array $overrides = [])
    {
        Sanctum::actingAs($owner);

        return $this->post('/api/v1/provider/verification', array_replace([
            'businessName' => 'Bromo Gear', 'address' => 'Jl. Ijen No. 3, Malang', 'bankAccount' => 'BCA 1234567890 a.n. Tania Putri',
            'nik' => '3573014101990002', 'ktpPhoto' => $this->photo(), 'selfiePhoto' => $this->photo(),
            'storePhotos' => [$this->photo(), $this->photo()],
        ], $overrides), ['Accept' => 'application/json']);
    }

    public function test_a_store_without_documents_cannot_be_verified(): void
    {
        $owner = $this->newProvider();
        $this->assertFalse(Provider::findOrFail($owner->provider_id)->hasDocuments());

        $response = $this->as('admin')->putJson("/api/v1/providers/{$owner->provider_id}/status", ['status' => 'verified']);
        $this->assertApiError($response, 'INVALID_STATE', 409);
        $this->assertSame('pending', Provider::findOrFail($owner->provider_id)->status);
    }

    public function test_documents_are_stored_privately_and_shown_masked(): void
    {
        $owner = $this->newProvider();
        $data = $this->submit($owner, ['businessName' => 'Bromo Gear Malang'])->assertOk()->json('data');

        $this->assertSame('pending', $data['status']);
        $this->assertSame('••••••••••••0002', $data['nikMasked']);
        $this->assertCount(2, $data['storePhotoUrls']);
        $store = Provider::findOrFail($owner->provider_id);
        $this->assertSame('Bromo Gear Malang', $store->business_name);
        $this->assertNotSame('3573014101990002', $store->getRawOriginal('owner_nik_enc'));
        Storage::disk('local')->assertExists($store->ktp_photo_path);
        $this->assertTrue(AuditLog::where('action', Audit::STORE_DOCUMENTS_SENT)->exists());

        // Daftar toko tidak membawa dokumen, hanya tanda bahwa dokumen sudah dikirim.
        $listed = collect($this->as('admin')->getJson('/api/v1/providers')->json('data'))->firstWhere('id', $store->id);
        $this->assertTrue($listed['documentsSubmitted']);
        $this->assertArrayNotHasKey('nikMasked', $listed);
    }

    public function test_only_the_owner_and_admin_see_the_documents(): void
    {
        $owner = $this->newProvider();
        $this->submit($owner)->assertOk();
        $id = $owner->provider_id;

        $this->as('admin')->getJson("/api/v1/providers/$id/verification")->assertOk();
        $this->as('admin')->get("/api/v1/files/providers/$id/ktp")->assertOk();
        Sanctum::actingAs($owner);
        $this->get("/api/v1/files/providers/$id/store-1")->assertOk();
        $this->assertApiError($this->getJson("/api/v1/files/providers/$id/store-2"), 'NOT_FOUND', 404);

        $this->assertApiError($this->as('sari')->getJson("/api/v1/providers/$id/verification"), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('budi')->getJson("/api/v1/files/providers/$id/selfie"), 'FORBIDDEN', 403);
    }

    public function test_admin_verifies_and_the_owner_gets_an_email(): void
    {
        $owner = $this->newProvider();
        $this->submit($owner)->assertOk();

        $this->as('admin')->putJson("/api/v1/providers/{$owner->provider_id}/status", ['status' => 'verified'])
            ->assertOk()->assertJsonPath('data.status', 'verified');
        $this->assertNotNull(Provider::findOrFail($owner->provider_id)->reviewed_at);
        Mail::assertSent(StoreVerificationResult::class,
            fn (StoreVerificationResult $mail) => $mail->hasTo('tania@mail.com') && $mail->verified);

        // Toko terverifikasi tidak mengirim dokumen lagi.
        $this->assertApiError($this->submit($owner), 'INVALID_STATE', 409);
    }

    public function test_a_rejection_needs_a_reason_and_the_owner_can_send_again(): void
    {
        $owner = $this->newProvider();
        $this->submit($owner)->assertOk();
        $id = $owner->provider_id;
        $oldKtp = Provider::findOrFail($id)->ktp_photo_path;

        $this->assertApiError($this->as('admin')->putJson("/api/v1/providers/$id/status", ['status' => 'rejected']), 'VALIDATION', 422);
        $this->putJson("/api/v1/providers/$id/status", ['status' => 'rejected', 'reason' => 'Foto KTP buram.'])->assertOk();
        Mail::assertSent(StoreVerificationResult::class,
            fn (StoreVerificationResult $mail) => ! $mail->verified && $mail->reason === 'Foto KTP buram.');
        $this->assertStringContainsString('Alasan: Foto KTP buram.', AuditLog::where('action', Audit::PROVIDER_STATUS)->value('detail'));

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/providers/$id/verification")
            ->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.rejectionReason', 'Foto KTP buram.');

        $this->submit($owner)->assertOk()->assertJsonPath('data.status', 'pending')->assertJsonPath('data.rejectionReason', null);
        Storage::disk('local')->assertMissing($oldKtp);
    }

    public function test_the_form_is_checked(): void
    {
        $owner = $this->newProvider();
        $this->assertSame('NIK harus 16 angka.', $this->submit($owner, ['nik' => '12345'])->assertStatus(422)->json('error.message'));
        $this->assertSame('Lampirkan minimal satu foto toko atau stok alat.',
            $this->submit($owner, ['storePhotos' => []])->assertStatus(422)->json('error.message'));
        $four = array_fill(0, 4, $this->photo());
        $this->assertSame('Foto toko paling banyak 3.', $this->submit($owner, ['storePhotos' => $four])->assertStatus(422)->json('error.message'));
        $this->assertApiError($this->as('budi')->post('/api/v1/provider/verification', [], ['Accept' => 'application/json']), 'FORBIDDEN', 403);
    }

    public function test_admin_sees_other_stores_with_the_same_owner_nik(): void
    {
        $first = $this->newProvider();
        $this->submit($first)->assertOk();
        $second = $this->newProvider('tania2@mail.com');
        $this->submit($second, ['businessName' => 'Bromo Gear 2'])->assertOk()->assertJsonPath('data.sameOwnerStores', []);

        $this->as('admin')->getJson("/api/v1/providers/{$second->provider_id}/verification")
            ->assertJsonPath('data.sameOwnerStores', ['Bromo Gear']);
    }

    public function test_a_mail_failure_does_not_undo_the_decision(): void
    {
        $owner = $this->newProvider();
        $this->submit($owner)->assertOk();
        Mail::shouldReceive('to->send')->andThrow(new RuntimeException('smtp mati'));

        $this->as('admin')->putJson("/api/v1/providers/{$owner->provider_id}/status", ['status' => 'verified'])->assertOk();
        $this->assertSame('verified', Provider::findOrFail($owner->provider_id)->status);
    }

    public function test_a_customer_opens_a_store_and_becomes_a_provider(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'role' => 'customer', 'name' => 'Tania Putri', 'email' => 'tania@mail.com', 'password' => 'rahasia123',
            'phone' => '081298765432', 'city' => 'Malang',
        ])->assertOk();
        $customer = User::where('email', 'tania@mail.com')->firstOrFail();
        Sanctum::actingAs($customer);

        $user = $this->postJson('/api/v1/provider/open', [
            'businessName' => 'Bromo Gear', 'address' => 'Jl. Ijen No. 3', 'bankAccount' => 'BCA 1234567890',
            'city' => 'Batu', 'phone' => '081298765432',
        ])->assertOk()->assertJsonPath('data.role', 'provider')->json('data');

        $store = Provider::findOrFail($user['providerId']);
        $this->assertSame(['pending', 'Batu', $customer->id], [$store->status, $store->city, $store->owner_id]);
        $this->assertFalse($store->hasDocuments());
        $this->assertTrue(AuditLog::where('action', Audit::STORE_OPENED)->exists());
    }

    public function test_opening_a_store_is_refused_while_rentals_run_or_when_blacklisted(): void
    {
        $form = [
            'businessName' => 'Budi Gear', 'address' => 'Jl. Ijen No. 3', 'bankAccount' => 'BCA 1234567890',
            'city' => 'Malang', 'phone' => '081234567801',
        ];
        // Budi masih punya sewa yang berjalan di data demo.
        $this->assertApiError($this->as('budi')->postJson('/api/v1/provider/open', $form), 'INVALID_STATE', 409);
        $this->assertApiError($this->as('sari')->postJson('/api/v1/provider/open', $form), 'FORBIDDEN', 403);

        BlacklistEntry::create(['customer_id' => 'u-rina', 'reason' => 'Tes', 'by' => 'Admin RentGear', 'at' => now()]);
        $this->assertApiError($this->as('rina')->postJson('/api/v1/provider/open', $form), 'BLACKLISTED', 403);
        $this->assertSame('customer', User::findOrFail('u-budi')->role);
    }
}
