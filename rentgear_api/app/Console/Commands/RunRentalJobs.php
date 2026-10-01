<?php

namespace App\Console\Commands;

use App\Services\RentalJobs;
use Illuminate\Console\Command;

class RunRentalJobs extends Command
{
    protected $signature = 'rentgear:run-jobs';

    protected $description = 'Tandai booking kedaluwarsa, batal, tidak diambil, dan terlambat';

    public function handle(RentalJobs $jobs): int
    {
        $this->info($jobs->run().' transaksi berubah.');

        return self::SUCCESS;
    }
}
