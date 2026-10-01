<?php

namespace App\Models;

use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Equipment extends Model
{
    use HasStringId;

    protected $table = 'equipment';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'price_per_day' => 'float',
            'deposit_amount' => 'float',
            'rating' => 'float',
            'is_active' => 'boolean',
        ];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(Provider::class);
    }

    public function sizes(): HasMany
    {
        return $this->hasMany(EquipmentSize::class)->orderBy('sort');
    }

    public function photos(): HasMany
    {
        return $this->hasMany(EquipmentPhoto::class)->orderBy('sort');
    }

    public function hasSizes(): bool
    {
        return $this->sizes->isNotEmpty();
    }

    /** Stok untuk satu ukuran, atau stok total bila alat tanpa ukuran. */
    public function stockFor(?string $size): int
    {
        if (! $this->hasSizes()) {
            return $this->stock;
        }

        return (int) $this->sizes->when($size !== null, fn ($s) => $s->where('label', $size))->sum('stock');
    }
}
