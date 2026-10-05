<?php

use App\Http\Controllers\Api\V1\AdminController;
use App\Http\Controllers\Api\V1\AiController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\FileController;
use App\Http\Controllers\Api\V1\ProviderController;
use App\Http\Controllers\Api\V1\RentalController;
use App\Http\Controllers\Api\V1\StoreController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // Dibatasi supaya password tidak bisa ditebak berulang-ulang dan akun tidak bisa dibuat beruntun.
    Route::middleware('throttle:20,1')->group(function () {
        Route::post('auth/login', [AuthController::class, 'login']);
        Route::post('auth/register', [AuthController::class, 'register']);
        Route::post('auth/google', [AuthController::class, 'google']);
    });
    Route::get('media/{path}', [FileController::class, 'media'])->where('path', '.*');

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('auth/me', [AuthController::class, 'me']);
        Route::post('auth/logout', [AuthController::class, 'logout']);

        Route::get('categories', [CatalogController::class, 'categories']);
        Route::get('equipment', [CatalogController::class, 'index']);
        Route::get('equipment/{id}', [CatalogController::class, 'show']);
        Route::get('equipment/{id}/availability', [CatalogController::class, 'availability']);

        Route::post('equipment', [ProviderController::class, 'storeEquipment']);
        // POST, bukan PUT: PHP hanya membaca berkas multipart pada POST.
        Route::post('equipment/{id}', [ProviderController::class, 'updateEquipment']);
        Route::put('provider/guarantee-policy', [ProviderController::class, 'guaranteePolicy']);
        Route::put('provider/location', [ProviderController::class, 'location']);
        Route::put('provider/fine-policy', [ProviderController::class, 'finePolicy']);

        Route::get('providers', [StoreController::class, 'index']);
        Route::get('providers/{id}', [StoreController::class, 'show']);
        Route::get('providers/{id}/equipment', [StoreController::class, 'equipment']);
        Route::get('providers/{id}/reviews', [StoreController::class, 'reviews']);
        Route::put('reviews/{id}/reply', [StoreController::class, 'reply']);
        Route::put('providers/{id}/follow', [StoreController::class, 'follow']);
        Route::delete('providers/{id}/follow', [StoreController::class, 'unfollow']);
        Route::get('me/follows', [StoreController::class, 'myFollows']);

        Route::get('rentals', [RentalController::class, 'index']);
        Route::post('rentals', [RentalController::class, 'store']);
        Route::get('rentals/{id}', [RentalController::class, 'show']);
        Route::post('rentals/{id}/guarantees/{guaranteeId}/review', [RentalController::class, 'reviewGuarantee']);
        Route::post('rentals/{id}/confirm', [RentalController::class, 'confirm']);
        Route::post('rentals/{id}/reject', [RentalController::class, 'reject']);
        Route::post('rentals/{id}/cancel', [RentalController::class, 'cancel']);
        Route::post('rentals/{id}/payment', [RentalController::class, 'payment']);
        Route::post('rentals/{id}/condition-photos', [RentalController::class, 'conditionPhoto']);
        Route::post('rentals/{id}/handover', [RentalController::class, 'handover']);
        Route::post('rentals/{id}/return', [RentalController::class, 'receiveReturn']);
        Route::post('rentals/{id}/complete', [RentalController::class, 'complete']);
        Route::post('rentals/{id}/damage-objection', [RentalController::class, 'damageObjection']);
        Route::post('rentals/{id}/damage-decision', [RentalController::class, 'damageDecision']);
        Route::post('rentals/{id}/review', [RentalController::class, 'review']);

        Route::get('files/guarantees/{guaranteeId}', [FileController::class, 'guarantee']);
        Route::get('files/payments/{rentalId}', [FileController::class, 'payment']);
        Route::get('files/condition/{photoId}', [FileController::class, 'condition']);

        Route::put('providers/{id}/status', [AdminController::class, 'providerStatus']);
        Route::get('customers', [AdminController::class, 'customers']);
        Route::get('audit', [AdminController::class, 'audit']);

        // Dibatasi supaya kuota Gemini tidak habis oleh satu pengguna.
        Route::middleware('throttle:15,1')->group(function () {
            Route::post('ai/recommend', [AiController::class, 'recommend']);
            Route::post('ai/rentals/{id}/fine-opinion', [AiController::class, 'fineOpinion']);
            Route::post('ai/customers/{id}/risk', [AiController::class, 'customerRisk']);
        });
        Route::put('customers/{id}/blacklist', [AdminController::class, 'blacklist']);
        Route::delete('customers/{id}/blacklist', [AdminController::class, 'unblacklist']);
        Route::get('me/blacklist', [AdminController::class, 'myBlacklist']);
    });
});
