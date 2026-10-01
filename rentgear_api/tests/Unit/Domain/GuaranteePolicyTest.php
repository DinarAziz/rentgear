<?php

namespace Tests\Unit\Domain;

use App\Domain\Guarantee\GuaranteePolicy;
use PHPUnit\Framework\TestCase;

/** Kasus yang sama dengan grup "GuaranteePolicy" di rentgear_app/test/domain_test.dart. */
class GuaranteePolicyTest extends TestCase
{
    private GuaranteePolicy $policy;

    protected function setUp(): void
    {
        $this->policy = new GuaranteePolicy(['ktp', 'ktm', 'ijazah'], highValueThreshold: 1000000, highValueRequired: 2);
    }

    private function draft(string $type, string $number, string $name = 'Budi Santoso', bool $photo = true): array
    {
        return ['type' => $type, 'holderName' => $name, 'documentNumber' => $number, 'hasPhoto' => $photo];
    }

    public function test_required_count_rises_for_high_value_rentals(): void
    {
        $this->assertSame(1, $this->policy->requiredCount(500000));
        $this->assertSame(2, $this->policy->requiredCount(1000000));
    }

    public function test_valid_single_ktp_passes(): void
    {
        $errors = $this->policy->validate([$this->draft('ktp', '3573011204020001')], 200000, 'budi  santoso');
        $this->assertSame([], $errors);
    }

    public function test_high_value_rental_needs_two_documents(): void
    {
        $errors = $this->policy->validate([$this->draft('ktp', '3573011204020001')], 1500000, 'Budi Santoso');
        $this->assertStringContainsString('minimal 2', implode("\n", $errors));
    }

    public function test_rejects_unaccepted_type_duplicate_bad_nik_other_name_missing_photo(): void
    {
        $errors = implode("\n", $this->policy->validate([
            $this->draft('sim', '123'),
            $this->draft('ktp', '12345'),
            $this->draft('ktp', '3573011204020001', 'Orang Lain'),
            $this->draft('ijazah', 'DN-01', photo: false),
        ], 100000, 'Budi Santoso'));

        foreach (['Maksimal 3', 'SIM tidak diterima', '16 digit', 'sudah dipakai', 'atas nama penyewa', 'foto dokumen wajib'] as $needle) {
            $this->assertStringContainsString($needle, $errors);
        }
    }

    public function test_unknown_or_missing_type_is_reported(): void
    {
        $errors = implode("\n", $this->policy->validate([$this->draft('', '1'), $this->draft('kartu-pelajar', '1')], 1000, 'Budi Santoso'));
        $this->assertSame(2, substr_count($errors, 'pilih jenis dokumen'));
    }

    public function test_masks_all_but_last_four_digits(): void
    {
        $this->assertSame('••••••••••••0001', GuaranteePolicy::mask('3573011204020001'));
        $this->assertSame('••••••••••••0001', GuaranteePolicy::mask('3573 0112 0402 0001'));
        $this->assertSame('••••', GuaranteePolicy::mask('123'));
    }
}
