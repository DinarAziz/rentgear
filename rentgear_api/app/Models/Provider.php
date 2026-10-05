<?php

namespace App\Models;

use App\Domain\Fines\FinePolicy;
use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

class Provider extends Model
{
    use HasStringId;

    public const PENDING = 'pending';

    public const VERIFIED = 'verified';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'accepted_types' => 'array',
            'fine_policy' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
            'high_value_threshold' => 'float',
        ];
    }

    public function finePolicy(): FinePolicy
    {
        return FinePolicy::fromArray($this->fine_policy);
    }

    /**
     * Rating, jumlah ulasan, dan jumlah pengikut dihitung dari tabel `reviews`
     * dan `follows`, tidak disimpan sebagai kolom.
     */
    public function scopeWithStats(Builder $query): void
    {
        $query->withCount('reviews')
            ->withAvg('reviews as rating_avg', 'rating')
            ->addSelect(['follower_count' => DB::table('follows')
                ->selectRaw('count(*)')->whereColumn('provider_id', 'providers.id')]);
    }

    public function equipment(): HasMany
    {
        return $this->hasMany(Equipment::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }
}
