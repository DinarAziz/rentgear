<?php

namespace Tests\Feature;

use Tests\ApiTestCase;

/** Kasus yang sama dengan rentgear_app/test/store_test.dart. */
class ReviewTest extends ApiTestCase
{
    public function test_reviews_come_only_from_the_renter_of_a_completed_rental_once(): void
    {
        $before = $this->as('budi')->getJson('/api/v1/providers/p-arjuna')->json('data');
        $total = $before['rating'] * $before['reviewCount'];

        // r-1 belum selesai, r-5 (Budi, Arjuna) sudah selesai.
        $this->assertApiError($this->postJson('/api/v1/rentals/r-1/review', ['rating' => 5]), 'INVALID_STATE', 409);
        $this->assertApiError($this->as('rina')->postJson('/api/v1/rentals/r-5/review', ['rating' => 5]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('sari')->postJson('/api/v1/rentals/r-5/review', ['rating' => 5]), 'FORBIDDEN', 403);
        $this->assertApiError($this->as('budi')->postJson('/api/v1/rentals/r-5/review', ['rating' => 0]), 'VALIDATION', 422);
        $this->assertApiError($this->postJson('/api/v1/rentals/r-5/review', ['rating' => 6]), 'VALIDATION', 422);

        $review = $this->postJson('/api/v1/rentals/r-5/review', ['rating' => 2, 'comment' => '  Sleeping bag lembap  '])
            ->assertOk()->json('data.review');
        $this->assertSame(2, $review['rating']);
        $this->assertSame('Sleeping bag lembap', $review['comment']);
        $this->assertSame('Budi Santoso', $review['customerName']);
        $this->assertSame('Sleeping Bag Polar', $review['equipmentName']);

        $after = $this->getJson('/api/v1/providers/p-arjuna')->json('data');
        $this->assertSame($before['reviewCount'] + 1, $after['reviewCount']);
        $this->assertEqualsWithDelta(($total + 2) / ($before['reviewCount'] + 1), $after['rating'], 0.001);
        $this->getJson('/api/v1/providers/p-arjuna/reviews')->assertJsonPath('data.0.comment', 'Sleeping bag lembap');

        $this->assertApiError($this->postJson('/api/v1/rentals/r-5/review', ['rating' => 5]), 'ALREADY_REVIEWED', 409);
    }
}
