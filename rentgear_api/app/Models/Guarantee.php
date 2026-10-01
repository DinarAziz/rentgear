<?php

namespace App\Models;

use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Model;

class Guarantee extends Model
{
    use HasStringId;

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            // Nomor dokumen adalah data pribadi: disimpan terenkripsi.
            'number_enc' => 'encrypted',
            'held_at' => 'datetime',
            'returned_at' => 'datetime',
        ];
    }
}
