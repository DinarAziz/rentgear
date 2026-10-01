<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class BlacklistEntry extends Model
{
    public $timestamps = false;

    public $incrementing = false;

    protected $primaryKey = 'customer_id';

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return ['at' => 'datetime'];
    }
}
