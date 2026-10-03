<?php

namespace App\Http\Presenters;

use App\Models\AuditLog;
use App\Models\BlacklistEntry;
use App\Models\Equipment;
use App\Models\Guarantee;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\Review;
use App\Models\User;
use DateTimeInterface;

/**
 * Bentuk JSON tiap model. Nama kunci camelCase, sama dengan nama field di
 * rentgear_app/lib/domain/models.dart.
 */
final class Present
{
    private static function time(?DateTimeInterface $at): ?string
    {
        return $at?->format(DATE_ATOM);
    }

    public static function user(User $u): array
    {
        return [
            'id' => $u->id, 'name' => $u->name, 'email' => $u->email, 'phone' => $u->phone,
            'role' => $u->role, 'city' => $u->city, 'providerId' => $u->provider_id,
        ];
    }

    public static function audit(AuditLog $a): array
    {
        return [
            'id' => (string) $a->id, 'at' => self::time($a->at), 'actorName' => $a->actor_name, 'actorRole' => $a->actor_role,
            'action' => $a->action, 'target' => $a->target, 'detail' => $a->detail,
        ];
    }

    /** Toko harus dimuat lewat `Provider::withStats()`. */
    public static function provider(Provider $p): array
    {
        return [
            'id' => $p->id, 'ownerId' => $p->owner_id, 'businessName' => $p->business_name, 'city' => $p->city,
            'address' => $p->address, 'status' => $p->status, 'latitude' => $p->latitude, 'longitude' => $p->longitude,
            'bankAccount' => $p->bank_account,
            'policy' => [
                'acceptedTypes' => $p->accepted_types,
                'baseRequired' => $p->base_required,
                'highValueThreshold' => $p->high_value_threshold,
                'highValueRequired' => $p->high_value_required,
            ],
            'finePolicy' => $p->finePolicy()->toArray(),
            'rating' => round((float) ($p->rating_avg ?? 0), 4),
            'reviewCount' => (int) ($p->reviews_count ?? 0),
            'followerCount' => (int) ($p->follower_count ?? 0),
        ];
    }

    /** Satu toko lengkap dengan statistiknya, dimuat ulang supaya angkanya terbaru. */
    public static function providerById(string $id): array
    {
        return self::provider(Provider::withStats()->findOrFail($id));
    }

    /**
     * Foto alat dilayani lewat rute API supaya ikut header CORS, yang dibutuhkan
     * Flutter web untuk memuat gambar dari alamat lain.
     */
    public static function photoUrl(?string $path): ?string
    {
        return $path === null ? null : url('api/v1/media/'.$path);
    }

    public static function equipment(Equipment $e): array
    {
        return [
            'id' => $e->id, 'providerId' => $e->provider_id, 'categoryId' => $e->category_id, 'name' => $e->name,
            'brand' => $e->brand, 'description' => $e->description, 'pricePerDay' => $e->price_per_day,
            'depositAmount' => $e->deposit_amount, 'weightGram' => $e->weight_gram, 'stock' => $e->stock,
            'sizes' => $e->sizes->map(fn ($s) => ['label' => $s->label, 'stock' => $s->stock])->all(),
            'photos' => $e->photos->map(fn ($p) => ['id' => $p->id, 'url' => self::photoUrl($p->path)])->all(),
            'rating' => $e->rating, 'conditionScore' => $e->condition_score,
            'capacityPerson' => $e->capacity_person, 'isActive' => $e->is_active,
        ];
    }

    public static function review(Review $r): array
    {
        return [
            'id' => $r->id, 'providerId' => $r->provider_id, 'customerName' => $r->customer_name,
            'rating' => $r->rating, 'comment' => $r->comment, 'at' => self::time($r->at),
            'rentalId' => $r->rental_id, 'equipmentName' => $r->equipment_name,
            'reply' => $r->reply, 'repliedAt' => self::time($r->replied_at),
        ];
    }

    /** Nomor dokumen tidak pernah dikirim utuh, hanya versi tersamar. */
    public static function guarantee(Guarantee $g): array
    {
        return [
            'id' => $g->id, 'type' => $g->type, 'holderName' => $g->holder_name,
            'maskedNumber' => $g->number_masked, 'hasPhoto' => $g->photo_path !== null,
            'status' => $g->status, 'note' => $g->note,
            'heldAt' => self::time($g->held_at), 'returnedAt' => self::time($g->returned_at),
        ];
    }

    /** Transaksi harus dimuat dengan relasi `guarantees`, `logs`, dan `review`. */
    public static function rental(Rental $r): array
    {
        return [
            'id' => $r->id, 'invoiceCode' => $r->invoice_code,
            'customerId' => $r->customer_id, 'customerName' => $r->customer_name,
            'providerId' => $r->provider_id, 'providerName' => $r->provider_name,
            'equipmentId' => $r->equipment_id, 'equipmentName' => $r->equipment_name,
            'categoryId' => $r->category_id, 'qty' => $r->qty, 'size' => $r->size,
            'photoUrl' => self::photoUrl($r->photo_path),
            'startDate' => $r->start_date->format('Y-m-d'), 'endDate' => $r->end_date->format('Y-m-d'),
            'pricePerDaySnapshot' => $r->price_per_day_snapshot, 'depositSnapshot' => $r->deposit_snapshot,
            'finePolicy' => $r->finePolicy()->toArray(),
            'status' => $r->status, 'createdAt' => self::time($r->created_at),
            'cancelReason' => $r->cancel_reason, 'hasPaymentProof' => $r->payment_proof_path !== null,
            'returnedAt' => self::time($r->returned_at), 'returnCondition' => $r->return_condition,
            'lateFee' => $r->late_fee, 'damageFee' => $r->damage_fee, 'damageNote' => $r->damage_note,
            'damageReview' => $r->damage_review, 'reviewReason' => $r->review_reason, 'reviewNote' => $r->review_note,
            'guarantees' => $r->guarantees->map(self::guarantee(...))->all(),
            // Fotonya diunduh lewat `files/condition/{id}`.
            'conditionPhotos' => $r->conditionPhotos->map(fn ($p) => [
                'id' => (string) $p->id, 'phase' => $p->phase, 'at' => self::time($p->at),
            ])->all(),
            'logs' => $r->logs->map(fn ($l) => [
                'from' => $l->from, 'to' => $l->to, 'actorName' => $l->actor_name,
                'at' => self::time($l->at), 'note' => $l->note,
            ])->all(),
            'review' => $r->review === null ? null : self::review($r->review),
        ];
    }

    public static function blacklist(?BlacklistEntry $b): ?array
    {
        return $b === null ? null : ['reason' => $b->reason, 'by' => $b->by, 'at' => self::time($b->at)];
    }
}
