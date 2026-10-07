<?php

namespace Tests\Unit\Domain;

use App\Domain\Rental\RentalStateMachine;
use App\Domain\Rental\RentalStatus;
use PHPUnit\Framework\TestCase;

class RentalStateMachineTest extends TestCase
{
    public function test_happy_path_is_allowed_for_the_right_actor(): void
    {
        $steps = [
            [RentalStatus::PendingConfirmation, RentalStatus::AwaitingPayment, 'provider', ['verified']],
            [RentalStatus::AwaitingPayment, RentalStatus::PaymentReview, 'customer', ['verified']],
            [RentalStatus::PaymentReview, RentalStatus::Paid, 'provider', ['verified']],
            [RentalStatus::PaymentReview, RentalStatus::AwaitingPayment, 'provider', ['verified']],
            [RentalStatus::Paid, RentalStatus::PickedUp, 'provider', ['held']],
            [RentalStatus::PickedUp, RentalStatus::Returned, 'provider', ['held']],
            [RentalStatus::Returned, RentalStatus::Completed, 'provider', ['returned']],
        ];
        foreach ($steps as [$from, $to, $role, $guarantees]) {
            $this->assertNull(RentalStateMachine::guardError($from, $to, $role, $guarantees), "$from->value to $to->value");
        }
    }

    public function test_skipping_a_step_is_refused(): void
    {
        $error = RentalStateMachine::guardError(RentalStatus::PendingConfirmation, RentalStatus::Paid, 'customer', ['verified']);
        $this->assertStringContainsString('tidak bisa diubah', $error);
    }

    public function test_wrong_actor_is_refused(): void
    {
        $error = RentalStateMachine::guardError(RentalStatus::PendingConfirmation, RentalStatus::AwaitingPayment, 'customer', ['verified']);
        $this->assertSame('Anda tidak berwenang melakukan aksi ini.', $error);
    }

    public function test_guarantee_guards(): void
    {
        $this->assertStringContainsString('harus diverifikasi', RentalStateMachine::guardError(
            RentalStatus::PendingConfirmation, RentalStatus::AwaitingPayment, 'provider', ['submitted']));
        $this->assertStringContainsString('harus diverifikasi', RentalStateMachine::guardError(
            RentalStatus::PendingConfirmation, RentalStatus::AwaitingPayment, 'provider', []));
        $this->assertStringContainsString('harus diterima', RentalStateMachine::guardError(
            RentalStatus::Paid, RentalStatus::PickedUp, 'provider', ['verified']));
        $this->assertStringContainsString('harus dikembalikan', RentalStateMachine::guardError(
            RentalStatus::Returned, RentalStatus::Completed, 'provider', ['held']));
    }

    public function test_system_jobs_use_a_null_actor(): void
    {
        $this->assertNull(RentalStateMachine::guardError(RentalStatus::PickedUp, RentalStatus::Overdue, null, ['held']));
        $this->assertNotNull(RentalStateMachine::guardError(RentalStatus::PickedUp, RentalStatus::Overdue, 'provider', ['held']));
    }

    public function test_locking_statuses_match_the_flutter_app(): void
    {
        $this->assertSame(
            ['pendingConfirmation', 'awaitingPayment', 'paymentReview', 'paid', 'pickedUp', 'overdue', 'returned'],
            RentalStateMachine::LOCKING,
        );
    }
}
