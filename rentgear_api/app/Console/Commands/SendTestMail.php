<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Mail\Message;
use Illuminate\Support\Facades\Mail;
use Throwable;

/** Memeriksa pengirim email (dipakai lupa password) tanpa lewat aplikasi. */
class SendTestMail extends Command
{
    protected $signature = 'rentgear:mail-test {email : Alamat yang dikirimi email percobaan}';

    protected $description = 'Kirim satu email percobaan untuk memeriksa pengaturan MAIL_* di .env';

    public function handle(): int
    {
        $mailer = config('mail.default');
        try {
            Mail::raw(
                'Ini email percobaan dari server RentGear. Jika Anda menerimanya, pengirim email sudah benar.',
                fn (Message $message) => $message->to($this->argument('email'))->subject('Email percobaan RentGear'),
            );
        } catch (Throwable $e) {
            $this->error("Gagal mengirim lewat \"$mailer\": ".$e->getMessage());

            return self::FAILURE;
        }

        if (in_array($mailer, ['log', 'array'], true)) {
            $this->warn("MAIL_MAILER masih \"$mailer\": email tidak dikirim ke mana pun, isinya hanya dicatat. Isi pengaturan SMTP di .env dulu.");

            return self::SUCCESS;
        }
        $this->info("Email dikirim lewat \"$mailer\" dari ".config('mail.from.address').'. Periksa kotak masuk dan folder Spam.');

        return self::SUCCESS;
    }
}
