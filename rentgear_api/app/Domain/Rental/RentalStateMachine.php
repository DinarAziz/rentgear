<?php

namespace App\Domain\Rental;

/**
 * Satu-satunya pintu perubahan status transaksi (docs/03 bagian 1).
 * Salinan dari rentgear_app/lib/domain/rental_state_machine.dart.
 */
final class RentalStateMachine
{
    private const ALLOWED = [
        'pendingConfirmation' => ['awaitingPayment', 'rejected', 'expired', 'cancelled'],
        'awaitingPayment' => ['paid', 'cancelled'],
        'paid' => ['pickedUp', 'noShow'],
        'pickedUp' => ['returned', 'overdue'],
        'overdue' => ['returned'],
        'returned' => ['completed', 'disputed'],
        'disputed' => ['completed'],
    ];

    /** Role yang boleh memicu status tujuan. `null` = job sistem. */
    private const ACTORS = [
        'awaitingPayment' => ['provider'],
        'rejected' => ['provider'],
        'cancelled' => ['customer', null], // null: tidak dibayar 24 jam
        'paid' => ['customer'],
        'pickedUp' => ['provider'],
        'returned' => ['provider'],
        'completed' => ['provider', 'admin'],
        'disputed' => ['customer', 'provider'],
        'expired' => [null],
        'noShow' => [null],
        'overdue' => [null],
    ];

    /** Status yang ikut mengunci stok pada perhitungan ALG-2. */
    public const LOCKING = ['pendingConfirmation', 'awaitingPayment', 'paid', 'pickedUp', 'overdue', 'returned'];

    public static function canTransition(RentalStatus $from, RentalStatus $to): bool
    {
        return in_array($to->value, self::ALLOWED[$from->value] ?? [], true);
    }

    /**
     * Pesan kesalahan, atau `null` bila transisi sah.
     *
     * @param  array<int, string>  $guaranteeStatuses  status tiap jaminan transaksi ini
     */
    public static function guardError(RentalStatus $from, RentalStatus $to, ?string $actorRole, array $guaranteeStatuses): ?string
    {
        if (! self::canTransition($from, $to)) {
            return "Status \"{$from->label()}\" tidak bisa diubah menjadi \"{$to->label()}\".";
        }
        if (! in_array($actorRole, self::ACTORS[$to->value] ?? [], true)) {
            return 'Anda tidak berwenang melakukan aksi ini.';
        }

        $allAre = fn (string $status) => array_filter($guaranteeStatuses, fn ($s) => $s !== $status) === [];

        return match ($to) {
            RentalStatus::AwaitingPayment => $guaranteeStatuses === [] || ! $allAre('verified')
                ? 'Semua jaminan harus diverifikasi sebelum konfirmasi.' : null,
            RentalStatus::PickedUp => ! $allAre('held')
                ? 'Dokumen asli jaminan harus diterima sebelum alat diserahkan.' : null,
            RentalStatus::Completed => ! $allAre('returned')
                ? 'Semua jaminan harus dikembalikan sebelum transaksi selesai.' : null,
            default => null,
        };
    }
}
