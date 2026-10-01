<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Presenters\Present;
use App\Models\User;
use App\Support\ApiException;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => 'required|string', 'password' => 'required|string']);
        $user = User::where('email', strtolower(trim($data['email'])))->first();
        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            throw new ApiException('AUTH_FAILED', 'Email atau password salah.');
        }

        return ApiResponse::ok([
            'token' => $user->createToken('app')->plainTextToken,
            'user' => Present::user($user),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return ApiResponse::ok(Present::user($request->user()));
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return ApiResponse::ok();
    }
}
