<?php

namespace App\Services;

use App\Domain\Guarantee\GuaranteePolicy;
use App\Mail\StoreVerificationResult;
use App\Models\BlacklistEntry;
use App\Models\Provider;
use App\Models\Rental;
use App\Models\User;
use App\Support\ApiException;
use App\Support\Audit;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * Verifikasi toko. Penyedia mengirim data toko dan dokumen (NIK, foto KTP, swafoto dengan KTP, foto toko), lalu admin
 * memeriksanya. Toko baru tampil di katalog setelah admin memverifikasi. Toko yang ditolak mendapat alasan dan bisa
 * mengirim ulang dokumennya.
 */
final class StoreVerificationService
{
    /** Status sewa yang sudah selesai. Penyewa dengan sewa di luar daftar ini belum boleh membuka toko. */
    private const FINAL_RENTAL_STATUSES = ['completed', 'rejected', 'cancelled', 'expired'];

    /** Sama dengan `ProviderStatus.label` di aplikasi. */
    public const STATUS_LABELS = ['pending' => 'Menunggu verifikasi', 'verified' => 'Terverifikasi', 'rejected' => 'Ditolak'];

    /**
     * Penyewa membuka toko. Akunnya menjadi akun penyedia dan tokonya menunggu dokumen verifikasi. Sewa yang masih
     * berjalan harus selesai dulu, karena akun penyedia tidak bisa mengurus sewa sebagai penyewa.
     */
    public function openStore(User $user, array $data): User
    {
        if (! $user->isCustomer()) {
            throw new ApiException('FORBIDDEN', 'Hanya akun penyewa yang bisa membuka toko.');
        }
        if (BlacklistEntry::find($user->id) !== null) {
            throw new ApiException('BLACKLISTED', 'Akun yang masuk blacklist tidak bisa membuka toko.');
        }
        $active = Rental::where('customer_id', $user->id)->whereNotIn('status', self::FINAL_RENTAL_STATUSES)->exists();
        if ($active) {
            throw new ApiException('INVALID_STATE', 'Selesaikan dulu sewa yang masih berjalan, lalu buka toko.');
        }

        DB::transaction(function () use ($user, $data) {
            $user->update(['role' => User::PROVIDER, 'phone' => $data['phone'], 'city' => trim($data['city'])]);
            $provider = Provider::create([
                'id' => 'p-'.strtolower((string) Str::ulid()), 'owner_id' => $user->id,
                'business_name' => trim($data['businessName']), 'city' => $user->city,
                'address' => trim($data['address']), 'bank_account' => trim($data['bankAccount']),
                'status' => Provider::PENDING, 'accepted_types' => ['ktp'],
                ...Provider::DEFAULT_LOCATION,
            ]);
            $user->update(['provider_id' => $provider->id]);
        });
        Audit::record($user, Audit::STORE_OPENED, $user->provider->business_name);

        return $user->refresh();
    }

    /**
     * Penyedia mengirim data toko dan dokumen. Kiriman baru menggantikan yang lama dan status kembali menunggu admin.
     *
     * @param  list<UploadedFile>  $storePhotos
     */
    public function submit(Provider $provider, User $owner, array $data, UploadedFile $ktp, UploadedFile $selfie, array $storePhotos): Provider
    {
        if ($provider->status === Provider::VERIFIED) {
            throw new ApiException('INVALID_STATE', 'Toko sudah terverifikasi.');
        }
        $nik = preg_replace('/\s/u', '', $data['nik']);
        $old = array_filter([$provider->ktp_photo_path, $provider->selfie_photo_path, ...($provider->store_photo_paths ?? [])]);

        // Nama berkas memakai id acak, supaya kiriman ulang tidak tertimpa sebelum data baru tersimpan.
        $dir = "store-verifications/{$provider->id}";
        $save = fn (UploadedFile $file, string $name) => $file->storeAs($dir, $name.'-'.Str::lower((string) Str::ulid()).'.'.$file->extension(), 'local');
        $provider->update([
            'business_name' => trim($data['businessName']), 'address' => trim($data['address']),
            'bank_account' => trim($data['bankAccount']),
            'owner_nik_enc' => $nik, 'owner_nik_masked' => GuaranteePolicy::mask($nik), 'owner_nik_hash' => Provider::nikHash($nik),
            'ktp_photo_path' => $save($ktp, 'ktp'), 'selfie_photo_path' => $save($selfie, 'selfie'),
            'store_photo_paths' => array_map(fn (UploadedFile $f) => $save($f, 'store'), $storePhotos),
            'status' => Provider::PENDING, 'submitted_at' => now(), 'reviewed_at' => null, 'rejection_reason' => null,
        ]);
        Storage::disk('local')->delete($old);
        Audit::record($owner, Audit::STORE_DOCUMENTS_SENT, $provider->business_name);

        return $provider;
    }

    /** Admin memverifikasi atau menolak toko. Menolak wajib dengan alasan, yang dibaca pemilik toko. */
    public function decide(Provider $provider, User $admin, string $status, ?string $reason): Provider
    {
        $reason = trim((string) $reason);
        if ($status === Provider::VERIFIED && ! $provider->hasDocuments()) {
            throw new ApiException('INVALID_STATE', 'Toko belum mengirim dokumen verifikasi.');
        }
        if ($status === Provider::REJECTED && $reason === '') {
            throw new ApiException('VALIDATION', 'Tulis alasan penolakan, supaya pemilik toko tahu yang harus diperbaiki.');
        }
        $before = $provider->status;
        $provider->update([
            'status' => $status,
            'reviewed_at' => $status === Provider::PENDING ? null : now(),
            'rejection_reason' => $status === Provider::REJECTED ? $reason : null,
        ]);
        $detail = 'Dari '.self::STATUS_LABELS[$before].' menjadi '.self::STATUS_LABELS[$status].'.';
        Audit::record($admin, Audit::PROVIDER_STATUS, $provider->business_name, $status === Provider::REJECTED ? "$detail Alasan: $reason" : $detail);
        if ($status !== Provider::PENDING && $status !== $before) {
            $this->notifyOwner($provider);
        }

        return $provider;
    }

    /**
     * Email hasil verifikasi ke pemilik toko. Bila email gagal terkirim, keputusan admin tetap berlaku; pemilik toko
     * tetap melihat hasilnya di aplikasi.
     */
    private function notifyOwner(Provider $provider): void
    {
        $owner = $provider->owner;
        if ($owner === null) {
            return;
        }
        try {
            Mail::to($owner->email)->send(new StoreVerificationResult(
                $owner->name, $provider->business_name, $provider->status === Provider::VERIFIED, $provider->rejection_reason));
        } catch (Throwable $e) {
            logger()->warning('Email verifikasi toko gagal: '.$e->getMessage());
        }
    }

    /** Toko lain dengan NIK pemilik yang sama. Admin perlu tahu bila satu orang membuka beberapa toko. */
    public function sameOwnerStores(Provider $provider): array
    {
        if ($provider->owner_nik_hash === null) {
            return [];
        }

        return Provider::where('owner_nik_hash', $provider->owner_nik_hash)->whereKeyNot($provider->id)
            ->orderBy('business_name')->pluck('business_name')->all();
    }

    /** Berkas dokumen menurut nama di rute: `ktp`, `selfie`, atau `store-0` sampai `store-2`. */
    public static function documentPath(Provider $provider, string $name): ?string
    {
        if (preg_match('/^store-(\d)$/', $name, $m) === 1) {
            return ($provider->store_photo_paths ?? [])[(int) $m[1]] ?? null;
        }

        return match ($name) {
            'ktp' => $provider->ktp_photo_path,
            'selfie' => $provider->selfie_photo_path,
            default => null,
        };
    }
}
