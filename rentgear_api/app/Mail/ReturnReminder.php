<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** Email ke penyewa sehari sebelum tanggal kembali, atau saat sewanya sudah terlambat. */
class ReturnReminder extends Mailable
{
    public function __construct(
        public readonly string $name,
        public readonly string $invoice,
        public readonly string $equipment,
        public readonly string $store,
        public readonly string $endDate,
        public readonly bool $overdue,
        public readonly float $lateFeePerDay,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: $this->overdue
            ? "Sewa {$this->invoice} sudah terlambat"
            : "Besok batas pengembalian {$this->equipment}");
    }

    public function content(): Content
    {
        return new Content(text: 'mail.return-reminder');
    }
}
