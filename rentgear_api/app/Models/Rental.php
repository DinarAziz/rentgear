<?php

namespace App\Models;

use App\Domain\Availability\AvailabilityService;
use App\Domain\Fines\FinePolicy;
use App\Domain\Rental\PriceCalculator;
use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Rental extends Model
{
    use HasStringId;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'start_date' => 'date:Y-m-d',
            'end_date' => 'date:Y-m-d',
            'reschedule_start' => 'date:Y-m-d',
            'reschedule_end' => 'date:Y-m-d',
            'returned_at' => 'datetime',
            'price_per_day_snapshot' => 'float',
            'deposit_snapshot' => 'float',
            'late_fee' => 'float',
            'damage_fee' => 'float',
            'fine_policy' => 'array',
        ];
    }

    public function guarantees(): HasMany
    {
        return $this->hasMany(Guarantee::class)->orderBy('id');
    }

    public function logs(): HasMany
    {
        return $this->hasMany(RentalStatusLog::class)->orderBy('id');
    }

    public function review(): HasOne
    {
        return $this->hasOne(Review::class);
    }

    /** Bukti transfer, terlama lebih dulu. Yang terakhir adalah kiriman yang berlaku. */
    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class)->orderBy('submitted_at')->orderBy('id');
    }

    public function latestPayment(): ?Payment
    {
        return $this->payments->last();
    }

    /** Nominal yang harus ditransfer: biaya sewa setelah diskon ditambah deposit. */
    public function amountDue(): float
    {
        return PriceCalculator::grandTotal($this->price_per_day_snapshot, $this->deposit_snapshot, $this->qty,
            AvailabilityService::inclusiveDays($this->start_date, $this->end_date), (int) $this->discount_percent);
    }

    public function conditionPhotos(): HasMany
    {
        return $this->hasMany(ConditionPhoto::class)->orderBy('id');
    }

    /** Aturan denda toko saat booking dibuat. Sewa lama tanpa salinan memakai aturan bawaan. */
    public function finePolicy(): FinePolicy
    {
        return FinePolicy::fromArray($this->fine_policy);
    }

    public function depositTotal(): float
    {
        return $this->deposit_snapshot * $this->qty;
    }
}
