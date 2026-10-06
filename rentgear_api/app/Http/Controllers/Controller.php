<?php

namespace App\Http\Controllers;

abstract class Controller
{
    /** Foto unggahan: hanya JPG, PNG, atau WebP (diperiksa dari isi berkas), paling besar 8 MB. */
    protected const PHOTO_RULE = 'mimes:jpg,jpeg,png,webp|max:8192';

    protected const PHOTO_MESSAGES = ['mimes' => 'Foto harus berupa JPG, PNG, atau WebP.', 'max' => 'Ukuran foto paling besar 8 MB.'];
}
