<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Fines\ReturnCondition;
use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\ConditionPhoto;
use App\Models\Rental;
use App\Services\BookingService;
use App\Services\RentalFlowService;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Enum;

class RentalController extends Controller
{
    public function __construct(private readonly RentalFlowService $flow) {}

    private function present(Rental $rental): JsonResponse
    {
        return ApiResponse::ok(Present::rental($rental->fresh(['guarantees', 'logs', 'review', 'conditionPhotos'])));
    }

    private function reason(Request $request): string
    {
        return $request->validate(['reason' => 'required|string|max:255'])['reason'];
    }

    /** Penyewa melihat sewanya, penyedia melihat pesanan tokonya, admin melihat semuanya. */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $rentals = Rental::with('guarantees', 'logs', 'review', 'conditionPhotos')
            ->when($user->isCustomer(), fn ($q) => $q->where('customer_id', $user->id))
            ->when($user->isProvider(), fn ($q) => $q->where('provider_id', $user->provider_id))
            ->orderByDesc('created_at')->orderByDesc('id')
            ->get();

        return ApiResponse::ok($rentals->map(Present::rental(...)));
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $rental = Rental::find($id) ?? throw new ApiException('NOT_FOUND', 'Transaksi tidak ditemukan.');
        self::authorizeView($rental, $request);

        return $this->present($rental);
    }

    /** Hanya penyewanya, pemilik tokonya, atau admin yang boleh melihat transaksi. */
    public static function authorizeView(Rental $rental, Request $request): void
    {
        $user = $request->user();
        $allowed = $user->isAdmin()
            || ($user->isCustomer() && $user->id === $rental->customer_id)
            || ($user->isProvider() && $user->provider_id === $rental->provider_id);
        if (! $allowed) {
            throw new ApiException('FORBIDDEN', 'Transaksi ini bukan milik Anda.');
        }
    }

    public function store(Request $request, BookingService $booking): JsonResponse
    {
        $data = $request->validate([
            'equipmentId' => 'required|string',
            'qty' => 'required|integer',
            'size' => 'nullable|string',
            'startDate' => 'required|date_format:Y-m-d',
            'endDate' => 'required|date_format:Y-m-d',
            'guarantees' => 'nullable|array',
            'guarantees.*.type' => 'nullable|string',
            'guarantees.*.holderName' => 'nullable|string',
            'guarantees.*.documentNumber' => 'nullable|string',
            'guarantees.*.photo' => 'nullable|'.self::PHOTO_RULE,
        ], self::PHOTO_MESSAGES);
        $key = $request->header('Idempotency-Key')
            ?? throw new ApiException('VALIDATION', 'Header Idempotency-Key wajib diisi.');

        // Foto ikut dari berkas unggahan, bukan dari isian yang sudah divalidasi sebagai teks.
        $guarantees = array_values($request->input('guarantees', []));
        foreach ($guarantees as $i => &$guarantee) {
            $guarantee['photo'] = $request->file("guarantees.$i.photo");
        }

        return $this->present($booking->create($request->user(), $data, $guarantees, $key));
    }

    public function reviewGuarantee(Request $request, string $id, string $guaranteeId): JsonResponse
    {
        $data = $request->validate(['accept' => 'required|boolean', 'note' => 'nullable|string|max:255']);

        return $this->present($this->flow->reviewGuarantee($id, $guaranteeId, $request->user(), (bool) $data['accept'], $data['note'] ?? null));
    }

    public function confirm(Request $request, string $id): JsonResponse
    {
        return $this->present($this->flow->confirm($id, $request->user()));
    }

    public function reject(Request $request, string $id): JsonResponse
    {
        $reason = $this->reason($request);

        return $this->present($this->flow->reject($id, $request->user(), $reason));
    }

    public function cancel(Request $request, string $id): JsonResponse
    {
        $reason = $this->reason($request);

        return $this->present($this->flow->cancel($id, $request->user(), $reason));
    }

    public function payment(Request $request, string $id): JsonResponse
    {
        $request->validate(['proof' => 'required|'.self::PHOTO_RULE], self::PHOTO_MESSAGES);

        return $this->present($this->flow->submitPayment($id, $request->user(), $request->file('proof')));
    }

    public function conditionPhoto(Request $request, string $id): JsonResponse
    {
        $data = $request->validate([
            'phase' => ['required', Rule::in([ConditionPhoto::HANDOVER, ConditionPhoto::RETURN])],
            'photo' => 'required|'.self::PHOTO_RULE,
        ], self::PHOTO_MESSAGES);

        return $this->present($this->flow->addConditionPhoto($id, $request->user(), $data['phase'], $request->file('photo')));
    }

    public function handover(Request $request, string $id): JsonResponse
    {
        return $this->present($this->flow->handover($id, $request->user()));
    }

    public function receiveReturn(Request $request, string $id): JsonResponse
    {
        $data = $request->validate([
            'condition' => ['nullable', new Enum(ReturnCondition::class)],
            'damageFee' => 'nullable|numeric',
            'damageNote' => 'nullable|string|max:255',
        ]);

        return $this->present($this->flow->receiveReturn(
            $id, $request->user(),
            ReturnCondition::from($data['condition'] ?? 'good'),
            (float) ($data['damageFee'] ?? 0),
            $data['damageNote'] ?? null,
        ));
    }

    public function complete(Request $request, string $id): JsonResponse
    {
        return $this->present($this->flow->complete($id, $request->user()));
    }

    public function damageObjection(Request $request, string $id): JsonResponse
    {
        $reason = $this->reason($request);

        return $this->present($this->flow->objectToDamageFee($id, $request->user(), $reason));
    }

    public function damageDecision(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['amount' => 'required|numeric', 'note' => 'nullable|string|max:255']);

        return $this->present($this->flow->decideDamageFee($id, $request->user(), (float) $data['amount'], $data['note'] ?? null));
    }

    public function review(Request $request, string $id): JsonResponse
    {
        $data = $request->validate(['rating' => 'required|integer', 'comment' => 'nullable|string|max:1000']);

        return $this->present($this->flow->submitReview($id, $request->user(), (int) $data['rating'], $data['comment'] ?? ''));
    }
}
