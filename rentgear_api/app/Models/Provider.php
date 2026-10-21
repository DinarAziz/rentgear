<?php

namespace App\Models;

use App\Domain\Fines\FinePolicy;
use App\Domain\Rental\DiscountPolicy;
use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

class Provider extends Model
{
    use HasStringId;

    public const PENDING = 'pending';

    public const VERIFIED = 'verified';

    public const REJECTED = 'rejected';

    /** Titik awal toko baru (Alun-alun Malang). Penyedia memindahkannya dari menu Profil. */
    public const DEFAULT_LOCATION = ['latitude' => -7.9826, 'longitude' => 112.6308];

    /** Batas foto toko yang dikirim untuk verifikasi. */
    public const MAX_STORE_PHOTOS = 3;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'accepted_types' => 'array',
            'fine_policy' => 'array',
            'discount_policy' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
            'high_value_threshold' => 'float',
            // NIK pemilik adalah data pribadi: disimpan terenkripsi.
            'owner_nik_enc' => 'encrypted',
            'store_photo_paths' => 'array',
            'submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
        ];
    }

    /** Dokumen verifikasi sudah dikirim, jadi admin bisa memeriksanya. */
    public function hasDocuments(): bool
    {
        return $this->submitted_at !== null;
    }

    /** Hash NIK untuk mencari toko lain dengan pemilik yang sama, tanpa membuka enkripsinya. */
    public static function nikHash(string $nik): string
    {
        return hash_hmac('sha256', $nik, (string) config('app.key'));
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function finePolicy(): FinePolicy
    {
        return FinePolicy::fromArray($this->fine_policy);
    }

    public function discountPolicy(): DiscountPolicy
    {
        return DiscountPolicy::fromArray($this->discount_policy);
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
