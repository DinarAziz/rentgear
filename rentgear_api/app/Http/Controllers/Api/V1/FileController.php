<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ConditionPhoto;
use App\Models\Guarantee;
use App\Models\Rental;
use App\Support\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/** Foto jaminan dan bukti transfer: data pribadi, hanya untuk pihak dalam transaksi dan admin. */
class FileController extends Controller
{
    public function guarantee(Request $request, string $guaranteeId): StreamedResponse
    {
        $guarantee = Guarantee::find($guaranteeId) ?? throw new ApiException('NOT_FOUND', 'Jaminan tidak ditemukan.');
        RentalController::authorizeView(Rental::findOrFail($guarantee->rental_id), $request);

        return $this->stream('local', $guarantee->photo_path);
    }

    public function payment(Request $request, string $rentalId): StreamedResponse
    {
        $rental = Rental::find($rentalId) ?? throw new ApiException('NOT_FOUND', 'Transaksi tidak ditemukan.');
        RentalController::authorizeView($rental, $request);

        return $this->stream('local', $rental->payment_proof_path);
    }

    public function condition(Request $request, string $photoId): StreamedResponse
    {
        $photo = ConditionPhoto::find($photoId) ?? throw new ApiException('NOT_FOUND', 'Foto tidak ditemukan.');
        RentalController::authorizeView(Rental::findOrFail($photo->rental_id), $request);

        return $this->stream('local', $photo->path);
    }

    /** Foto alat bersifat publik: tampil di katalog tanpa login. */
    public function media(string $path): StreamedResponse
    {
        if (str_contains($path, '..') || ! str_starts_with($path, 'equipment/')) {
            throw new ApiException('NOT_FOUND', 'Berkas tidak ditemukan.');
        }

        return $this->stream('public', $path, ['Cache-Control' => 'public, max-age=86400']);
    }

    private function stream(string $diskName, ?string $path, array $headers = []): StreamedResponse
    {
        $disk = Storage::disk($diskName);
        if ($path === null || ! $disk->exists($path)) {
            throw new ApiException('NOT_FOUND', 'Berkas tidak ditemukan.');
        }

        return $disk->response($path, null, $headers);
    }
}
