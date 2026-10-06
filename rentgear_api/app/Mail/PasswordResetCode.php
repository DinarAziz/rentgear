<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** Email berisi kode 6 angka untuk mengganti password yang terlupa. */
class PasswordResetCode extends Mailable
{
    public function __construct(public readonly string $name, public readonly string $code, public readonly int $minutes) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Kode ganti password RentGear');
    }

    public function content(): Content
    {
        return new Content(text: 'mail.password-reset-code');
    }
}
