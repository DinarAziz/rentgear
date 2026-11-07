<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\Category;
use App\Models\Equipment;
use App\Models\Provider;
use App\Services\AvailabilityQuery;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CatalogController extends Controller
{
    public function categories(): JsonResponse
    {
        return ApiResponse::ok(Category::orderBy('sort')->get(['id', 'name']));
    }

    /** Alat yang tampil di katalog: aktif dan tokonya sudah terverifikasi. */
    public function index(Request $request): JsonResponse
    {
        $query = trim((string) $request->query('query', ''));
        $items = Equipment::with('sizes', 'photos')
            ->where('is_active', true)
            ->whereHas('provider', fn ($p) => $p->where('status', Provider::VERIFIED))
            ->when($request->query('categoryId'), fn ($q, $category) => $q->where('category_id', $category))
            ->when($query !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('name', 'like', "%$query%")->orWhere('brand', 'like', "%$query%")))
            ->orderBy('created_at')->orderBy('id')
            ->get();

        return ApiResponse::ok($items->map(Present::equipment(...)));
    }

    public function show(string $id): JsonResponse
    {
        return ApiResponse::ok(Present::equipment(Equipment::with('sizes', 'photos')->findOrFail($id)));
    }

    public function availability(Request $request, string $id, AvailabilityQuery $availability): JsonResponse
    {
        $data = $request->validate([
            'start' => 'required|date_format:Y-m-d',
            'end' => 'required|date_format:Y-m-d|after_or_equal:start',
            'size' => 'nullable|string',
        ]);
        $equipment = Equipment::with('sizes')->findOrFail($id);

        return ApiResponse::ok([
            'available' => $availability->available($equipment, $data['start'], $data['end'], $data['size'] ?? null),
            'sizes' => (object) $availability->bySize($equipment, $data['start'], $data['end']),
        ]);
    }

    /** Id alat favorit penyewa yang sedang masuk. */
    public function myWishlist(Request $request): JsonResponse
    {
        return ApiResponse::ok(DB::table('wishlists')->where('customer_id', $request->user()->id)
            ->orderByDesc('created_at')->pluck('equipment_id'));
    }

    public function addToWishlist(Request $request, string $id): JsonResponse
    {
        return $this->setWishlist($request, $id, true);
    }

    public function removeFromWishlist(Request $request, string $id): JsonResponse
    {
        return $this->setWishlist($request, $id, false);
    }

    private function setWishlist(Request $request, string $equipmentId, bool $add): JsonResponse
    {
        $user = $request->user();
        if (! $user->isCustomer()) {
            throw new ApiException('FORBIDDEN', 'Hanya penyewa yang bisa menyimpan alat favorit.');
        }
        Equipment::findOrFail($equipmentId);

        $row = ['customer_id' => $user->id, 'equipment_id' => $equipmentId];
        $add ? DB::table('wishlists')->insertOrIgnore($row + ['created_at' => now()])
            : DB::table('wishlists')->where($row)->delete();

        return $this->myWishlist($request);
    }
}
