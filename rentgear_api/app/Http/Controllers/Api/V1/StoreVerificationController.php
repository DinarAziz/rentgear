<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\Provider;
use App\Services\StoreVerificationService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\StreamedResponse;

/** Buka toko dari akun penyewa, kirim dokumen verifikasi, dan lihat dokumen itu (pemilik toko dan admin). */
class StoreVerificationController extends Controller
{
    /** Data toko yang diisi saat membuka toko dan saat mengirim dokumen verifikasi. */
    private const STORE_RULES = [
        'businessName' => 'required|string|max:100', 'address' => 'required|string|max:200',
        'bankAccount' => 'required|string|max:100',
    ];

    private const STORE_MESSAGES = [
        'required' => 'Lengkapi semua isian.',
        'max' => 'Salah satu isian terlalu panjang.',
        'phone.regex' => 'Nomor HP tidak benar.',
    ];

    public function __construct(private readonly StoreVerificationService $service) {}

    public function open(Request $request): JsonResponse
    {
        $data = $request->validate([
            ...self::STORE_RULES, 'city' => 'required|string|max:60',
            'phone' => ['required', 'string', 'regex:/^\+?[0-9]{9,15}$/'],
        ], self::STORE_MESSAGES);

        return ApiResponse::ok(Present::user($this->service->openStore($request->user(), $data)));
    }

    public function submit(Request $request): JsonResponse
    {
        $user = $request->user();
        $provider = $user->isProvider() ? Provider::find($user->provider_id) : null;
        if ($provider === null) {
            throw new ApiException('FORBIDDEN', 'Bukan toko Anda.');
        }
        $data = $request->validate([
            ...self::STORE_RULES,
            'nik' => ['required', 'string', 'regex:/^\s*[0-9]{16}\s*$/'],
            'ktpPhoto' => 'required|'.self::PHOTO_RULE, 'selfiePhoto' => 'required|'.self::PHOTO_RULE,
            'storePhotos' => 'required|array|min:1|max:'.Provider::MAX_STORE_PHOTOS,
            'storePhotos.*' => self::PHOTO_RULE,
        ], [
            ...self::STORE_MESSAGES, ...self::PHOTO_MESSAGES,
            'nik.regex' => 'NIK harus 16 angka.',
            'ktpPhoto.required' => 'Lampirkan foto KTP.',
            'selfiePhoto.required' => 'Lampirkan foto diri sambil memegang KTP.',
            'storePhotos.required' => 'Lampirkan minimal satu foto toko atau stok alat.',
            'storePhotos.min' => 'Lampirkan minimal satu foto toko atau stok alat.',
            'storePhotos.max' => 'Foto toko paling banyak '.Provider::MAX_STORE_PHOTOS.'.',
        ]);
        $provider = $this->service->submit($provider, $user, $data,
            $request->file('ktpPhoto'), $request->file('selfiePhoto'), array_values($request->file('storePhotos')));

        return ApiResponse::ok(Present::verification($provider, []));
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $provider = $this->viewable($request, $id);
        // Hanya admin yang melihat toko lain milik orang yang sama.
        $sameOwner = $request->user()->isAdmin() ? $this->service->sameOwnerStores($provider) : [];

        return ApiResponse::ok(Present::verification($provider, $sameOwner));
    }

    public function file(Request $request, string $id, string $name): StreamedResponse
    {
        $path = StoreVerificationService::documentPath($this->viewable($request, $id), $name);
        $disk = Storage::disk('local');
        if ($path === null || ! $disk->exists($path)) {
            throw new ApiException('NOT_FOUND', 'Berkas tidak ditemukan.');
        }

        return $disk->response($path);
    }

    /** Dokumen verifikasi adalah data pribadi: hanya pemilik toko dan admin. */
    private function viewable(Request $request, string $id): Provider
    {
        $provider = Provider::find($id) ?? throw new ApiException('NOT_FOUND', 'Penyedia tidak ditemukan.');
        $user = $request->user();
        if (! $user->isAdmin() && $user->provider_id !== $provider->id) {
            throw new ApiException('FORBIDDEN', 'Dokumen ini hanya untuk pemilik toko dan admin.');
        }

        return $provider;
    }
}
