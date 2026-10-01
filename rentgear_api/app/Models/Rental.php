<?php

namespace App\Models;

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
            'returned_at' => 'datetime',
            'price_per_day_snapshot' => 'float',
            'deposit_snapshot' => 'float',
            'late_fee' => 'float',
            'damage_fee' => 'float',
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

    public function depositTotal(): float
    {
        return $this->deposit_snapshot * $this->qty;
    }
}
