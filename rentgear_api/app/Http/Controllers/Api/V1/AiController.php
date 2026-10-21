<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Rental;
use App\Models\User;
use App\Services\AiAdvisor;
use App\Support\ApiException;
use App\Support\ApiResponse;
use App\Support\Audit;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

/** Saran dari AI. Tidak ada rute di sini yang mengubah data transaksi. */
class AiController extends Controller
{
    public function __construct(private readonly AiAdvisor $advisor) {}

    /** Batas saran paket alat per akun per hari, supaya AI tidak dipakai untuk hal lain dalam jumlah banyak. */
    public const DAILY_RECOMMENDATIONS = 20;

    private const TRIP_LIMIT = 200;

    public function recommend(Request $request): JsonResponse
    {
        $data = $request->validate([
            'trip' => 'required|string|min:3|max:'.self::TRIP_LIMIT, 'people' => 'required|integer|min:1|max:20',
            'days' => 'required|integer|min:1|max:14',
        ], ['trip.max' => 'Rencana perjalanan paling banyak '.self::TRIP_LIMIT.' huruf.']);
        // Baris baru dan karakter kontrol dibuang; rencana cukup satu kalimat.
        $trip = trim(preg_replace('/[\p{C}\s]+/u', ' ', $data['trip']));
        if (preg_match_all('/\p{L}/u', $trip) < 3) {
            throw new ApiException('AI_OFF_TOPIC', AiAdvisor::OFF_TOPIC_MESSAGE);
        }

        $limit = 'ai-recommend:'.$request->user()->id;
        if (RateLimiter::tooManyAttempts($limit, self::DAILY_RECOMMENDATIONS)) {
            throw new ApiException('TOO_MANY_REQUESTS', 'Batas saran AI hari ini sudah habis. Coba lagi besok.');
        }
        RateLimiter::hit($limit, 86400);

        return ApiResponse::ok($this->advisor->recommend($trip, (int) $data['people'], (int) $data['days']));
    }

    public function fineOpinion(Request $request, string $id): JsonResponse
    {
        $admin = $this->requireAdmin($request);
        $rental = Rental::find($id) ?? throw new ApiException('NOT_FOUND', 'Transaksi tidak ditemukan.');
        if ($rental->return_condition === null) {
            throw new ApiException('INVALID_STATE', 'Alat belum dikembalikan, jadi belum ada denda untuk dinilai.');
        }
        $opinion = $this->advisor->fineOpinion($rental);
        Audit::record($admin, Audit::AI_FINE_OPINION, $rental->invoice_code);

        return ApiResponse::ok($opinion);
    }

    public function customerRisk(Request $request, string $id): JsonResponse
    {
        $admin = $this->requireAdmin($request);
        $customer = User::where('role', User::CUSTOMER)->find($id)
            ?? throw new ApiException('NOT_FOUND', 'Penyewa tidak ditemukan.');
        $risk = $this->advisor->customerRisk($customer);
        Audit::record($admin, Audit::AI_CUSTOMER_RISK, $customer->name);

        return ApiResponse::ok($risk);
    }

    private function requireAdmin(Request $request): User
    {
        $user = $request->user();
        if (! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya admin yang boleh melakukan aksi ini.');
        }

        return $user;
    }
}
