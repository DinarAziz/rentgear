<?php

use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Di hosting, server ada di belakang nginx dan Cloudflare. Tanpa ini alamat foto menjadi http dan
        // alamat IP di jejak audit menjadi 127.0.0.1.
        $middleware->trustProxies(at: '*');
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Semua galat API memakai amplop yang sama dengan kode `AppException` di Flutter.
        $exceptions->render(fn (ApiException $e) => ApiResponse::error($e->errorCode, $e->getMessage(), $e->status()));
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            return $request->is('api/*')
                ? ApiResponse::error('UNAUTHENTICATED', 'Sesi berakhir. Silakan masuk lagi.', 401) : null;
        });
        $exceptions->render(function (ValidationException $e, Request $request) {
            return $request->is('api/*')
                ? ApiResponse::error('VALIDATION', implode("\n", array_unique($e->validator->errors()->all())), 422) : null;
        });
        $exceptions->render(function (NotFoundHttpException $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }
            $missing = $e->getPrevious() instanceof ModelNotFoundException ? 'Data tidak ditemukan.' : 'Alamat tidak ditemukan.';

            return ApiResponse::error('NOT_FOUND', $missing, 404);
        });
    })->create();
