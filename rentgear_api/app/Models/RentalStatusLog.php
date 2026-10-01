<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RentalStatusLog extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['at' => 'datetime'];
    }
}
