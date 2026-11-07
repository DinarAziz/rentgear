<?php

namespace Tests\Feature;

use App\Mail\ReturnReminder;
use App\Models\Rental;
use App\Services\RentalJobs;
use Illuminate\Support\Facades\Mail;
use Tests\ApiTestCase;

class ReturnReminderTest extends ApiTestCase
{
    public function test_renter_gets_one_reminder_the_day_before_and_one_notice_when_late(): void
    {
        Mail::fake();
        $jobs = app(RentalJobs::class);
        $rental = Rental::findOrFail('r-4');
        $rental->update(['end_date' => now()->addDay()->format('Y-m-d')]);

        $jobs->run();
        Mail::assertSent(ReturnReminder::class, fn (ReturnReminder $m) => $m->invoice === $rental->invoice_code && ! $m->overdue);
        $sent = count(Mail::sent(ReturnReminder::class));
        $jobs->run();
        $this->assertCount($sent, Mail::sent(ReturnReminder::class), 'Pengingat H-1 tidak boleh dikirim dua kali.');

        $this->travel(2)->days();
        $jobs->run();
        $this->assertSame('overdue', $rental->fresh()->status);
        Mail::assertSent(ReturnReminder::class, fn (ReturnReminder $m) => $m->invoice === $rental->invoice_code && $m->overdue);
        $sent = count(Mail::sent(ReturnReminder::class));
        $jobs->run();
        $this->assertCount($sent, Mail::sent(ReturnReminder::class), 'Pemberitahuan terlambat tidak boleh dikirim dua kali.');
    }

    public function test_the_reminder_text_renders(): void
    {
        $text = (new ReturnReminder('Budi', 'INV-1', 'Tenda', 'Arjuna Outdoor', '9 November 2026', true, 25000))->render();
        $this->assertStringContainsString('Rp25.000 per hari', $text);
        $this->assertStringContainsString('sudah terlambat', (new ReturnReminder('Budi', 'INV-1', 'Tenda', 'Arjuna Outdoor', '9 November 2026', true, 25000))->envelope()->subject);
    }
}
