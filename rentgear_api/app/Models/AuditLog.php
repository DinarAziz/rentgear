<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Satu baris jejak audit. Tidak ada kode yang mengubah atau menghapus baris ini. */
class AuditLog extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['at' => 'datetime'];
    }
}
