<?php

use Illuminate\Support\Facades\Schedule;

// Pengganti pekerjaan yang dijalankan aplikasi Flutter saat dibuka.
Schedule::command('rentgear:run-jobs')->everyTenMinutes();
