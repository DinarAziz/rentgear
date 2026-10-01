<?php

namespace App\Models;

use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasStringId;

    public const CUSTOMER = 'customer';

    public const PROVIDER = 'provider';

    public const ADMIN = 'admin';

    protected $guarded = [];

    protected $hidden = ['password'];

    protected function casts(): array
    {
        return ['password' => 'hashed'];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(Provider::class);
    }

    public function isCustomer(): bool
    {
        return $this->role === self::CUSTOMER;
    }

    public function isProvider(): bool
    {
        return $this->role === self::PROVIDER;
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ADMIN;
    }
}
