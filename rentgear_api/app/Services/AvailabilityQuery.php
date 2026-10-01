<?php

namespace App\Services;

use App\Domain\Availability\AvailabilityService;
use App\Domain\Rental\RentalStateMachine;
use App\Models\Equipment;
use App\Models\Rental;

/** Mengambil booking yang mengunci stok dari database, lalu menghitungnya dengan ALG-2. */
final class AvailabilityQuery
{
    /**
     * `$size` null untuk alat tanpa ukuran. Untuk alat berukuran, null berarti
     * jumlah ketersediaan semua ukuran.
     */
    public function available(Equipment $equipment, string $start, string $end, ?string $size = null): int
    {
        if ($equipment->hasSizes() && $size === null) {
            return (int) $equipment->sizes->sum(fn ($s) => $this->available($equipment, $start, $end, $s->label));
        }

        $ranges = Rental::query()
            ->where('equipment_id', $equipment->id)
            ->where('size', $size)
            ->whereIn('status', RentalStateMachine::LOCKING)
            ->get(['start_date', 'end_date', 'qty'])
            ->map(fn (Rental $r) => [$r->start_date, $r->end_date, $r->qty])
            ->all();

        return AvailabilityService::available($equipment->stockFor($size), $ranges, $start, $end);
    }

    /** @return array<string, int> ketersediaan tiap ukuran, mis. ['41' => 2, '42' => 0] */
    public function bySize(Equipment $equipment, string $start, string $end): array
    {
        return $equipment->sizes
            ->mapWithKeys(fn ($s) => [$s->label => $this->available($equipment, $start, $end, $s->label)])
            ->all();
    }
}
