<?php

use Illuminate\Support\Facades\Schedule;

// Pengganti pekerjaan yang dijalankan aplikasi Flutter saat dibuka.
Schedule::command('rentgear:run-jobs')->everyTenMinutes();

// Token masuk yang sudah kedaluwarsa dibuang dari tabel.
Schedule::command('sanctum:prune-expired --hours=24')->daily();
