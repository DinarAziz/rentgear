<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\BlacklistEntry;
use App\Models\Provider;
use App\Models\User;
use App\Services\BlacklistService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    public function __construct(private readonly BlacklistService $blacklist) {}

    private function requireAdmin(Request $request): User
    {
        $user = $request->user();
        if (! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya admin yang boleh melakukan aksi ini.');
        }

        return $user;
    }

    private function customer(string $id): User
    {
        return User::where('role', User::CUSTOMER)->find($id)
            ?? throw new ApiException('NOT_FOUND', 'Penyewa tidak ditemukan.');
    }

    public function providerStatus(Request $request, string $id): JsonResponse
    {
        $this->requireAdmin($request);
        $data = $request->validate(['status' => ['required', Rule::in(['pending', 'verified', 'rejected'])]]);
        $provider = Provider::find($id) ?? throw new ApiException('NOT_FOUND', 'Penyedia tidak ditemukan.');
        $provider->update(['status' => $data['status']]);

        return ApiResponse::ok(Present::providerById($id));
    }

    /** Riwayat semua penyewa. */
    public function customers(Request $request): JsonResponse
    {
        $this->requireAdmin($request);
        $records = User::where('role', User::CUSTOMER)->orderBy('created_at')->orderBy('id')->get()
            ->map(function (User $customer) {
                $record = $this->blacklist->recordOf($customer);

                return [...$record, 'user' => Present::user($customer), 'blacklist' => Present::blacklist($record['blacklist'])];
            });

        return ApiResponse::ok($records);
    }

    public function blacklist(Request $request, string $id): JsonResponse
    {
        $admin = $this->requireAdmin($request);
        $this->blacklist->block($this->customer($id), $admin, $request->input('reason'));

        return ApiResponse::ok();
    }

    public function unblacklist(Request $request, string $id): JsonResponse
    {
        $this->requireAdmin($request);
        $this->blacklist->unblock($this->customer($id));

        return ApiResponse::ok();
    }

    /** Data blacklist pengguna yang sedang login, atau null. */
    public function myBlacklist(Request $request): JsonResponse
    {
        return ApiResponse::ok(Present::blacklist(BlacklistEntry::find($request->user()->id)));
    }
}
