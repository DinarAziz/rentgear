<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\Equipment;
use App\Models\Provider;
use App\Models\Review;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StoreController extends Controller
{
    public function index(): JsonResponse
    {
        return ApiResponse::ok(Provider::withStats()->orderBy('created_at')->orderBy('id')->get()->map(Present::provider(...)));
    }

    public function show(string $id): JsonResponse
    {
        return ApiResponse::ok(Present::providerById($id));
    }

    /** Semua alat toko, termasuk yang disembunyikan (dipakai layar "Alat Saya"). */
    public function equipment(string $id): JsonResponse
    {
        Provider::findOrFail($id);
        $items = Equipment::with('sizes', 'photos')->where('provider_id', $id)->orderBy('created_at')->orderBy('id')->get();

        return ApiResponse::ok($items->map(Present::equipment(...)));
    }

    public function reviews(string $id): JsonResponse
    {
        Provider::findOrFail($id);

        return ApiResponse::ok(Review::where('provider_id', $id)->orderByDesc('at')->get()->map(Present::review(...)));
    }

    /** Penyedia membalas ulasan tokonya. Balasan baru menggantikan yang lama. */
    public function reply(Request $request, string $id): JsonResponse
    {
        $review = Review::findOrFail($id);
        $user = $request->user();
        if (! $user->isProvider() || $user->provider_id !== $review->provider_id) {
            throw new ApiException('FORBIDDEN', 'Hanya pemilik toko yang bisa membalas ulasan.');
        }
        $data = $request->validate(['reply' => 'required|string|max:500']);
        $review->update(['reply' => trim($data['reply']), 'replied_at' => now()]);

        return ApiResponse::ok(Present::review($review));
    }

    public function follow(Request $request, string $id): JsonResponse
    {
        return $this->setFollow($request, $id, true);
    }

    public function unfollow(Request $request, string $id): JsonResponse
    {
        return $this->setFollow($request, $id, false);
    }

    private function setFollow(Request $request, string $providerId, bool $follow): JsonResponse
    {
        $user = $request->user();
        if (! $user->isCustomer()) {
            throw new ApiException('FORBIDDEN', 'Hanya penyewa yang bisa mengikuti toko.');
        }
        Provider::findOrFail($providerId);

        $row = ['customer_id' => $user->id, 'provider_id' => $providerId];
        $follow ? DB::table('follows')->insertOrIgnore($row) : DB::table('follows')->where($row)->delete();

        return ApiResponse::ok(Present::providerById($providerId));
    }

    public function myFollows(Request $request): JsonResponse
    {
        return ApiResponse::ok(DB::table('follows')->where('customer_id', $request->user()->id)->pluck('provider_id'));
    }
}
