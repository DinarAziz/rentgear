<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use Tests\ApiTestCase;

class AuditTest extends ApiTestCase
{
    private function actions(): array
    {
        return AuditLog::orderBy('id')->pluck('action')->all();
    }

    public function test_admin_actions_leave_a_trail(): void
    {
        $this->as('admin')->putJson('/api/v1/providers/p-puncak/status', ['status' => 'verified'])->assertOk();
        $this->putJson('/api/v1/customers/u-budi/blacklist', ['reason' => 'Tidak mengembalikan alat'])->assertOk();
        $this->deleteJson('/api/v1/customers/u-budi/blacklist')->assertOk();

        $this->assertSame(['provider_status', 'blacklist_added', 'blacklist_removed'], $this->actions());

        $log = $this->getJson('/api/v1/audit')->assertOk()->json('data');
        // Terbaru lebih dulu.
        $this->assertSame('blacklist_removed', $log[0]['action']);
        $this->assertSame('Budi Santoso', $log[1]['target']);
        $this->assertSame('Tidak mengembalikan alat', $log[1]['detail']);
        $this->assertSame('Puncak Outdoor', $log[2]['target']);
        $this->assertSame('Dari Menunggu verifikasi menjadi Terverifikasi.', $log[2]['detail']);
        $this->assertSame('admin', $log[2]['actorRole']);
        $this->assertNotEmpty($log[2]['actorName']);
    }

    public function test_logins_are_recorded_including_failed_ones(): void
    {
        $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => 'salah']);
        $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => 'password'])->assertOk();

        $this->assertSame(['login_failed', 'login'], $this->actions());
        $failed = AuditLog::orderBy('id')->first();
        $this->assertNull($failed->actor_id);
        $this->assertSame('budi@rentgear.id', $failed->target);
        // Password tidak pernah ikut tercatat.
        $this->assertStringNotContainsString('salah', json_encode(AuditLog::all()));
    }

    public function test_only_admin_reads_the_trail_and_nobody_can_change_it(): void
    {
        $this->assertApiError($this->as('budi')->getJson('/api/v1/audit'), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('sari')->getJson('/api/v1/audit'), 'FORBIDDEN', 403);

        $this->as('admin')->putJson('/api/v1/providers/p-puncak/status', ['status' => 'rejected'])->assertOk();
        $id = AuditLog::firstOrFail()->id;
        $this->deleteJson("/api/v1/audit/$id")->assertStatus(404);
        $this->putJson("/api/v1/audit/$id", ['detail' => 'x'])->assertStatus(404);
        $this->deleteJson('/api/v1/audit')->assertStatus(405);
        $this->assertSame(1, AuditLog::count());
    }
}
