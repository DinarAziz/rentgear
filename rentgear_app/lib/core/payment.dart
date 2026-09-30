/// Halaman pembayaran Lynk.id milik platform. Semua pelanggan membayar ke
/// sini; penyedia menerima dana dari platform. Bisa diganti saat build:
/// `flutter build apk --dart-define=LYNK_URL=https://lynk.id/nama/produk`.
const lynkPaymentUrl = String.fromEnvironment(
  'LYNK_URL',
  defaultValue: 'https://lynk.id/pembayaranbaik',
);
