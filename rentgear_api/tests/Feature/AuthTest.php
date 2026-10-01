<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

class AuthTest extends ApiTestCase
{
    public function test_login_returns_a_token_and_the_user(): void
    {
        $response = $this->postJson('/api/v1/auth/login', ['email' => ' Budi@RentGear.id ', 'password' => 'password']);

        $response->assertOk()->assertJsonPath('data.user.id', 'u-budi')->assertJsonPath('data.user.role', 'customer');
        $token = $response->json('data.token');
        $this->assertNotEmpty($token);

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()->assertJsonPath('data.email', 'budi@rentgear.id');
    }

    public function test_provider_login_carries_the_store_id(): void
    {
        $this->postJson('/api/v1/auth/login', ['email' => 'sari@rentgear.id', 'password' => 'password'])
            ->assertJsonPath('data.user.providerId', 'p-arjuna');
    }

    public function test_wrong_password_is_refused(): void
    {
        $response = $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => 'salah']);
        $this->assertApiError($response, 'AUTH_FAILED', 401);
        $this->assertSame('Email atau password salah.', $response->json('error.message'));
    }

    public function test_requests_without_a_token_get_the_error_envelope(): void
    {
        $this->assertApiError($this->getJson('/api/v1/equipment'), 'UNAUTHENTICATED', 401);
    }

    public function test_logout_revokes_the_token(): void
    {
        $token = $this->postJson('/api/v1/auth/login', ['email' => 'budi@rentgear.id', 'password' => 'password'])->json('data.token');
        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->assertApiError($this->withToken($token)->getJson('/api/v1/auth/me'), 'UNAUTHENTICATED', 401);
    }
}
