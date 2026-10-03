<?php

namespace App\Support;

use RuntimeException;

/**
 * Kesalahan bisnis dengan kode yang sama seperti `AppException` di aplikasi Flutter.
 * Dirender sebagai `{ "success": false, "error": { "code", "message" } }`.
 */
class ApiException extends RuntimeException
{
    private const STATUS = [
        'AUTH_FAILED' => 401,
        'UNAUTHENTICATED' => 401,
        'FORBIDDEN' => 403,
        'BLACKLISTED' => 403,
        'NOT_FOUND' => 404,
        'INVALID_TRANSITION' => 409,
        'INVALID_STATE' => 409,
        'SLOT_UNAVAILABLE' => 409,
        'ALREADY_REVIEWED' => 409,
        'DAMAGE_REVIEW_PENDING' => 409,
        'GOOGLE_NOT_CONFIGURED' => 503,
    ];

    public function __construct(public readonly string $errorCode, string $message)
    {
        parent::__construct($message);
    }

    public function status(): int
    {
        return self::STATUS[$this->errorCode] ?? 422;
    }
}
