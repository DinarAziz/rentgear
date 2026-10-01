<?php

namespace Tests\Feature;

use App\Models\Rental;
use App\Services\RentalJobs;
use Tests\ApiTestCase;

class JobsTest extends ApiTestCase
{
    public function test_scheduled_jobs_expire_cancel_no_show_and_flag_overdue(): void
    {
        // Data demo dibuat hari ini, lalu server berjalan 2 hari kemudian.
        $this->travel(2)->days();
        $jobs = app(RentalJobs::class);

        $this->assertSame(5, $jobs->run());
        $status = fn (string $id) => Rental::find($id)->status;
        $this->assertSame('expired', $status('r-1'));
        $this->assertSame('cancelled', $status('r-2'));
        $this->assertSame('noShow', $status('r-3'));
        $this->assertSame('overdue', $status('r-4'));
        $this->assertSame('overdue', $status('r-6'));
        $this->assertSame('completed', $status('r-5'));

        $rental = Rental::with('logs')->find('r-4');
        $this->assertSame('Sistem', $rental->logs->last()->actor_name);
        $this->assertSame('Penyedia tidak merespons dalam 12 jam', Rental::find('r-1')->cancel_reason);
        $this->assertSame(0, $jobs->run());
    }

    public function test_fresh_data_only_flags_the_overdue_demo_rental(): void
    {
        $this->artisan('rentgear:run-jobs')->expectsOutput('1 transaksi berubah.')->assertSuccessful();
        $this->assertSame('overdue', Rental::find('r-6')->status);
        $this->assertSame('pendingConfirmation', Rental::find('r-1')->status);
    }

    public function test_expired_bookings_release_their_stock(): void
    {
        $this->afterDays(2);
        // r-1 dan r-2 tidak lagi mengunci tenda dome.
        $this->as('budi')->getJson("/api/v1/equipment/e-dome4/availability?start={$this->day(1)}&end={$this->day(4)}")
            ->assertJsonPath('data.available', 3);
    }
}
