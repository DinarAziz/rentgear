<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

/**
 * Kunci utama berupa string. Data demo memakai id yang sama dengan aplikasi
 * Flutter (mis. "p-arjuna"); baris baru mendapat ULID.
 */
trait HasStringId
{
    public static function bootHasStringId(): void
    {
        static::creating(function ($model) {
            if (empty($model->getKey())) {
                $model->setAttribute($model->getKeyName(), strtolower((string) Str::ulid()));
            }
        });
    }

    public function initializeHasStringId(): void
    {
        $this->incrementing = false;
        $this->keyType = 'string';
    }
}
