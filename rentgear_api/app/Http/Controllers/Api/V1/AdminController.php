<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\AuditLog;
use App\Models\BlacklistEntry;
use App\Models\Provider;
use App\Models\User;
use App\Services\BlacklistService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use App\Support\Audit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    /** Sama dengan `ProviderStatus.label` di aplikasi. */
    private const STATUS_LABELS = ['pending' => 'Menunggu verifikasi', 'verified' => 'Terverifikasi', 'rejected' => 'Ditolak'];

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
        $admin = $this->requireAdmin($request);
        $data = $request->validate(['status' => ['required', Rule::in(['pending', 'verified', 'rejected'])]]);
        $provider = Provider::find($id) ?? throw new ApiException('NOT_FOUND', 'Penyedia tidak ditemukan.');
        $before = $provider->status;
        $provider->update(['status' => $data['status']]);
        Audit::record($admin, Audit::PROVIDER_STATUS, $provider->business_name,
            'Dari '.self::STATUS_LABELS[$before].' menjadi '.self::STATUS_LABELS[$data['status']].'.');

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
        $customer = $this->customer($id);
        $this->blacklist->block($customer, $admin, $request->input('reason'));
        Audit::record($admin, Audit::BLACKLIST_ADDED, $customer->name, trim((string) $request->input('reason')));

        return ApiResponse::ok();
    }

    public function unblacklist(Request $request, string $id): JsonResponse
    {
        $admin = $this->requireAdmin($request);
        $customer = $this->customer($id);
        $this->blacklist->unblock($customer);
        Audit::record($admin, Audit::BLACKLIST_REMOVED, $customer->name);

        return ApiResponse::ok();
    }

    /** Jejak audit terbaru lebih dulu. Hanya bisa dibaca; tidak ada rute untuk mengubah atau menghapusnya. */
    public function audit(Request $request): JsonResponse
    {
        $this->requireAdmin($request);

        return ApiResponse::ok(AuditLog::orderByDesc('id')->limit(300)->get()->map(Present::audit(...)));
    }

    /** Data blacklist pengguna yang sedang login, atau null. */
    public function myBlacklist(Request $request): JsonResponse
    {
        return ApiResponse::ok(Present::blacklist(BlacklistEntry::find($request->user()->id)));
    }
}
