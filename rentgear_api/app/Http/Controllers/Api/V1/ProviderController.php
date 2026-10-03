<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Fines\FinePolicy;
use App\Domain\Guarantee\GuaranteePolicy;
use App\Domain\Guarantee\GuaranteeType;
use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\Provider;
use App\Services\EquipmentService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Enum;

/** Aksi penyedia atas tokonya sendiri: alat dan aturan jaminan. */
class ProviderController extends Controller
{
    public function storeEquipment(Request $request, EquipmentService $service): JsonResponse
    {
        return $this->save($request, $service, null);
    }

    public function updateEquipment(Request $request, EquipmentService $service, string $id): JsonResponse
    {
        return $this->save($request, $service, $id);
    }

    private function save(Request $request, EquipmentService $service, ?string $id): JsonResponse
    {
        $data = $request->validate([
            'categoryId' => 'nullable|string', 'name' => 'nullable|string|max:120', 'brand' => 'nullable|string|max:120',
            'description' => 'nullable|string|max:2000', 'pricePerDay' => 'nullable|numeric',
            'depositAmount' => 'nullable|numeric', 'weightGram' => 'nullable|integer', 'stock' => 'nullable|integer',
            'capacityPerson' => 'nullable|integer', 'isActive' => 'nullable|boolean',
            'sizes' => 'nullable|array', 'sizes.*.label' => 'nullable|string|max:20', 'sizes.*.stock' => 'nullable|integer',
            'photoOrder' => 'nullable|array', 'photoOrder.*' => 'string',
            'newPhotos' => 'nullable|array', 'newPhotos.*' => 'image|max:8192',
        ]);

        // `photoOrder` berisi "keep:<id foto lama>" atau "new:<indeks di newPhotos>", sesuai urutan tampil.
        $photos = [];
        foreach ($data['photoOrder'] ?? [] as $entry) {
            [$kind, $value] = array_pad(explode(':', $entry, 2), 2, '');
            $photo = $kind === 'new' ? $request->file("newPhotos.$value") : $value;
            if ($photo !== null && $photo !== '') {
                $photos[] = $photo;
            }
        }

        $equipment = $service->save($request->user(), $id, $data, array_values($data['sizes'] ?? []), $photos);

        return ApiResponse::ok(Present::equipment($equipment));
    }

    public function guaranteePolicy(Request $request): JsonResponse
    {
        $provider = $this->ownStore($request);
        $data = $request->validate([
            'acceptedTypes' => 'present|array', 'acceptedTypes.*' => [new Enum(GuaranteeType::class)],
            'baseRequired' => 'required|integer|min:1|max:3', 'highValueRequired' => 'required|integer|min:1|max:3',
            'highValueThreshold' => 'required|numeric|min:0',
        ]);

        $types = array_values(array_unique($data['acceptedTypes']));
        if ($types === []) {
            throw new ApiException('VALIDATION', 'Pilih minimal satu jenis jaminan.');
        }
        $policy = new GuaranteePolicy($types, $data['baseRequired'], $data['highValueThreshold'], $data['highValueRequired']);
        if (count($types) < $policy->requiredCount(PHP_FLOAT_MAX)) {
            throw new ApiException('VALIDATION', 'Jenis jaminan yang diterima lebih sedikit dari jumlah jaminan yang diminta.');
        }
        $provider->update([
            'accepted_types' => $types, 'base_required' => $data['baseRequired'],
            'high_value_threshold' => $data['highValueThreshold'], 'high_value_required' => $data['highValueRequired'],
        ]);

        return ApiResponse::ok(Present::providerById($provider->id));
    }

    /** Penyedia memindahkan titik tokonya di peta. */
    public function location(Request $request): JsonResponse
    {
        $provider = $this->ownStore($request);
        $data = $request->validate([
            'latitude' => 'required|numeric|between:-90,90', 'longitude' => 'required|numeric|between:-180,180',
        ]);
        $provider->update($data);

        return ApiResponse::ok(Present::providerById($provider->id));
    }

    /** Penyedia mengatur aturan denda tokonya. Berlaku untuk booking berikutnya, bukan sewa yang sudah dipesan. */
    public function finePolicy(Request $request): JsonResponse
    {
        $provider = $this->ownStore($request);
        $data = $request->validate([
            'lateMultiplier' => 'required|numeric', 'graceHours' => 'required|integer',
            'minorDamagePercent' => 'required|integer', 'majorDamagePercent' => 'required|integer',
            'lostPercent' => 'required|integer',
        ]);
        $policy = FinePolicy::fromArray($data);
        if (($error = $policy->error()) !== null) {
            throw new ApiException('VALIDATION', $error);
        }
        $provider->update(['fine_policy' => $policy->toArray()]);

        return ApiResponse::ok(Present::providerById($provider->id));
    }

    /** Toko milik penyedia yang sedang masuk. Peran lain ditolak. */
    private function ownStore(Request $request): Provider
    {
        $user = $request->user();
        $provider = $user->isProvider() ? Provider::find($user->provider_id) : null;
        if ($provider === null) {
            throw new ApiException('FORBIDDEN', 'Bukan toko Anda.');
        }

        return $provider;
    }
}
