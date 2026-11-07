Halo {{ $name }},

@if ($overdue)
Sewa {{ $invoice }} ({{ $equipment }} dari {{ $store }}) seharusnya dikembalikan pada {{ $endDate }} dan sampai sekarang belum diterima toko.

Segera kembalikan alatnya ke {{ $store }}. Denda keterlambatan Rp{{ number_format($lateFeePerDay, 0, ',', '.') }} per hari dan bertambah setiap hari.
@else
Batas pengembalian {{ $equipment }} dari {{ $store }} (sewa {{ $invoice }}) adalah {{ $endDate }}.

Kembalikan alat paling lambat tanggal itu supaya tidak kena denda keterlambatan Rp{{ number_format($lateFeePerDay, 0, ',', '.') }} per hari.
@endif

Saat mengembalikan, buka detail sewa di aplikasi RentGear dan tunjukkan QR serah terima ke petugas toko.

RentGear
