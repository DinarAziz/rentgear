Halo {{ $name }},

@if ($verified)
Toko {{ $storeName }} sudah diverifikasi admin RentGear. Alat yang aktif di toko Anda sekarang tampil di katalog dan bisa disewa.
@else
Admin RentGear belum bisa memverifikasi toko {{ $storeName }}.

Alasan: {{ $reason }}

Buka aplikasi RentGear, masuk ke Profil, lalu pilih "Verifikasi toko". Perbaiki data atau dokumen yang disebut di atas, lalu kirim ulang.
@endif

RentGear
