<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** Email ke pemilik toko setelah admin memverifikasi atau menolak tokonya. */
class StoreVerificationResult extends Mailable
{
    public function __construct(
        public readonly string $name,
        public readonly string $storeName,
        public readonly bool $verified,
        public readonly ?string $reason,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: $this->verified
            ? "Toko {$this->storeName} sudah terverifikasi"
            : "Verifikasi toko {$this->storeName} ditolak");
    }

    public function content(): Content
    {
        return new Content(text: 'mail.store-verification-result');
    }
}
