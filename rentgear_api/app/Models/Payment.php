<?php

namespace App\Models;

use App\Models\Concerns\HasStringId;
use App\Support\ApiException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Satu kali penyewa mengirim bukti transfer untuk sebuah sewa. Nominalnya dikunci saat bukti dikirim. Penyedia
 * menerima atau menolaknya; bukti yang ditolak tetap tersimpan, dan penyewa mengirim bukti baru sebagai baris baru.
 */
class Payment extends Model
{
    use HasStringId;

    public const SUBMITTED = 'submitted';

    public const ACCEPTED = 'accepted';

    public const REJECTED = 'rejected';

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['amount' => 'float', 'submitted_at' => 'datetime', 'reviewed_at' => 'datetime'];
    }

    public function rental(): BelongsTo
    {
        return $this->belongsTo(Rental::class);
    }

    public function isOpen(): bool
    {
        return $this->status === self::SUBMITTED;
    }

    /** Penyedia memutuskan bukti transfer. Bukti yang sudah diputuskan tidak bisa diputuskan lagi. */
    public function review(bool $accept, string $reviewer, ?string $reason = null): void
    {
        if (! $this->isOpen()) {
            throw new ApiException('INVALID_STATE', 'Bukti transfer ini sudah diperiksa.');
        }
        $this->update([
            'status' => $accept ? self::ACCEPTED : self::REJECTED,
            'note' => $accept ? null : $reason, 'reviewed_at' => now(), 'reviewed_by' => $reviewer,
        ]);
    }
}
