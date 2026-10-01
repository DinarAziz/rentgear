<?php

namespace App\Models;

use App\Models\Concerns\HasStringId;
use Illuminate\Database\Eloquent\Model;

class EquipmentPhoto extends Model
{
    use HasStringId;

    public $timestamps = false;

    protected $guarded = [];
}
