<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Satu foto kondisi alat pada sebuah transaksi. */
class ConditionPhoto extends Model
{
    public const HANDOVER = 'handover';

    public const RETURN = 'return';

    /** Paling banyak foto per tahap. */
    public const MAX_PER_PHASE = 4;

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['at' => 'datetime'];
    }
}
