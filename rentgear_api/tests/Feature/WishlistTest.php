<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

class WishlistTest extends ApiTestCase
{
    public function test_renter_saves_and_removes_favourites(): void
    {
        $this->as('budi')->putJson('/api/v1/equipment/e-kompor/wishlist')->assertOk()->assertJsonPath('data', ['e-kompor']);
        $this->putJson('/api/v1/equipment/e-kompor/wishlist')->assertJsonCount(1, 'data');
        $this->getJson('/api/v1/me/wishlist')->assertJsonPath('data', ['e-kompor']);

        $this->as('rina')->getJson('/api/v1/me/wishlist')->assertJsonPath('data', []);

        $this->as('budi')->deleteJson('/api/v1/equipment/e-kompor/wishlist')->assertJsonPath('data', []);
    }

    public function test_only_renters_and_only_existing_gear(): void
    {
        $this->assertApiError($this->as('sari')->putJson('/api/v1/equipment/e-kompor/wishlist'), 'FORBIDDEN', 403);
        $this->as('budi')->putJson('/api/v1/equipment/tidak-ada/wishlist')->assertNotFound();
    }
}
