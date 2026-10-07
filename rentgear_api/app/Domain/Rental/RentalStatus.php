<?php

namespace App\Domain\Rental;

/** Nilai string sama dengan nama enum di aplikasi Flutter. */
enum RentalStatus: string
{
    case PendingConfirmation = 'pendingConfirmation';
    case AwaitingPayment = 'awaitingPayment';
    case PaymentReview = 'paymentReview';
    case Paid = 'paid';
    case PickedUp = 'pickedUp';
    case Overdue = 'overdue';
    case Returned = 'returned';
    case Completed = 'completed';
    case Rejected = 'rejected';
    case Cancelled = 'cancelled';
    case Expired = 'expired';
    case NoShow = 'noShow';
    case Disputed = 'disputed';

    public function label(): string
    {
        return match ($this) {
            self::PendingConfirmation => 'Menunggu konfirmasi',
            self::AwaitingPayment => 'Menunggu pembayaran',
            self::PaymentReview => 'Pembayaran diperiksa',
            self::Paid => 'Siap diambil',
            self::PickedUp => 'Sedang disewa',
            self::Overdue => 'Terlambat',
            self::Returned => 'Sudah dikembalikan',
            self::Completed => 'Selesai',
            self::Rejected => 'Ditolak',
            self::Cancelled => 'Dibatalkan',
            self::Expired => 'Kedaluwarsa',
            self::NoShow => 'Tidak diambil',
            self::Disputed => 'Sengketa',
        };
    }
}
