<?php

namespace App\Support;

use App\Models\AuditLog;
use App\Models\User;

/** Mencatat jejak audit: siapa melakukan apa, kapan, pada apa. */
final class Audit
{
    public const LOGIN = 'login';

    public const LOGIN_GOOGLE = 'login_google';

    public const REGISTER_GOOGLE = 'register_google';

    public const LOGIN_FAILED = 'login_failed';

    public const PROVIDER_STATUS = 'provider_status';

    public const DAMAGE_FEE_DECIDED = 'damage_fee_decided';

    public const BLACKLIST_ADDED = 'blacklist_added';

    public const BLACKLIST_REMOVED = 'blacklist_removed';

    public const AI_FINE_OPINION = 'ai_fine_opinion';

    public const AI_CUSTOMER_RISK = 'ai_customer_risk';

    /** [actor] kosong berarti Sistem, atau orang yang belum dikenali (gagal masuk). */
    public static function record(?User $actor, string $action, ?string $target = null, ?string $detail = null, string $anonymous = 'Sistem'): void
    {
        AuditLog::create([
            'at' => now(),
            'actor_id' => $actor?->id,
            'actor_name' => $actor?->name ?? $anonymous,
            'actor_role' => $actor?->role ?? 'system',
            'action' => $action,
            'target' => $target,
            'detail' => $detail,
            'ip' => request()?->ip(),
        ]);
    }
}
