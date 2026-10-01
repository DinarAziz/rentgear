<?php

namespace Tests\Feature;

use App\Models\BlacklistEntry;
use App\Models\Rental;
use App\Models\User;
use App\Services\BlacklistService;
use Tests\ApiTestCase;

class BlacklistTest extends ApiTestCase
{
    public function test_blacklisted_customer_cannot_book_until_the_admin_clears_it(): void
    {
        $this->assertApiError($this->as('admin')->putJson('/api/v1/customers/u-budi/blacklist', ['reason' => '  ']), 'VALIDATION', 422);

        $this->putJson('/api/v1/customers/u-budi/blacklist', ['reason' => 'Tidak mengembalikan alat'])->assertOk();
        $this->as('budi')->getJson('/api/v1/me/blacklist')
            ->assertJsonPath('data.reason', 'Tidak mengembalikan alat')->assertJsonPath('data.by', 'Admin RentGear');
        $response = $this->book([], 'a');
        $this->assertApiError($response, 'BLACKLISTED', 403);
        $this->assertStringContainsString('Tidak mengembalikan alat', $response->json('error.message'));

        $this->as('admin')->deleteJson('/api/v1/customers/u-budi/blacklist')->assertOk();
        $this->as('budi')->getJson('/api/v1/me/blacklist')->assertJsonPath('data', null);
        $this->book([], 'b')->assertOk()->assertJsonPath('data.status', 'pendingConfirmation');
    }

    public function test_admin_sees_each_customers_history(): void
    {
        $records = collect($this->as('admin')->getJson('/api/v1/customers')->assertOk()->json('data'))->keyBy('user.id');

        $this->assertSame(['u-budi', 'u-rina'], $records->keys()->sort()->values()->all());
        $budi = $records['u-budi'];
        $this->assertSame(3, $budi['rentalCount']);
        $this->assertSame(0, $budi['lateCount'] + $budi['noShowCount'] + $budi['damageCount']);
        $this->assertEquals(0, $budi['fineTotal']);
        $this->assertNull($budi['blacklist']);
    }

    public function test_only_customers_can_be_blacklisted(): void
    {
        $this->assertApiError($this->as('admin')->putJson('/api/v1/customers/u-sari/blacklist', ['reason' => 'x']), 'NOT_FOUND', 404);
    }

    public function test_late_return_counts_as_a_violation(): void
    {
        $this->afterDays(4);
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return')->assertOk();

        $budi = collect($this->as('admin')->getJson('/api/v1/customers')->json('data'))->firstWhere('user.id', 'u-budi');
        $this->assertSame(1, $budi['lateCount']);
        $this->assertGreaterThan(0, $budi['fineTotal']);
        $this->assertNull($budi['blacklist']);
    }

    public function test_third_violation_blacklists_automatically_and_clearing_resets_the_count(): void
    {
        // Dua pelanggaran lama Budi: dua sewa yang dulu dikembalikan terlambat.
        Rental::whereIn('id', ['r-1', 'r-5'])->update(['late_fee' => 10000]);
        $service = app(BlacklistService::class);
        $service->autoBlacklist('u-budi');
        $this->assertNull(BlacklistEntry::find('u-budi'));

        // Pelanggaran ketiga: r-4 terlambat.
        $this->afterDays(4);
        $this->as('dewi')->postJson('/api/v1/rentals/r-4/return')->assertOk();

        $entry = BlacklistEntry::find('u-budi');
        $this->assertSame('Sistem', $entry->by);
        $this->assertStringContainsString('3 pelanggaran', $entry->reason);

        // Setelah dicabut admin, pelanggaran lama tidak langsung mem-blacklist lagi.
        $this->as('admin')->deleteJson('/api/v1/customers/u-budi/blacklist')->assertOk();
        $this->assertSame(3, User::find('u-budi')->violation_baseline);
        $service->autoBlacklist('u-budi');
        $this->assertNull(BlacklistEntry::find('u-budi'));
    }
}
