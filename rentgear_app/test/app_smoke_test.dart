import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rentgear/app.dart';
import 'package:rentgear/core/location.dart';
import 'package:rentgear/core/maps.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/state/app_state.dart';

Future<LocationResult> noLocation({required bool ask}) async =>
    (status: LocationStatus.unknown, point: null);

/// Pengguna berada di Lumajang, dekat Semeru Camp Rent.
Future<LocationResult> inLumajang({required bool ask}) async =>
    (status: LocationStatus.found, point: const LatLng(-8.13, 113.22));

Future<void> pumpApp(WidgetTester tester, {LocationFinder findLocation = noLocation}) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Peta tidak mengambil ubin dari jaringan selama tes.
  debugTileProvider = BlankTileProvider();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) =>
        AppState(LocalRentGearRepository.open(latency: Duration.zero), findLocation: findLocation),
    child: const RentGearApp(),
  ));
}

void main() {
  testWidgets('customer opens catalog, detail and booking form', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi'), findsOneWidget);

    // Halaman awal menampilkan toko yang terverifikasi, bukan langsung alat.
    expect(find.text('Arjuna Outdoor'), findsOneWidget);
    expect(find.text('Semeru Camp Rent'), findsOneWidget);
    expect(find.text('Puncak Outdoor'), findsNothing);
    expect(find.text('Tenda Dome 4 Orang'), findsNothing);

    await tester.tap(find.text('Arjuna Outdoor'));
    await tester.pumpAndSettle();
    expect(find.text('Buka di Google Maps'), findsOneWidget);
    await tester.tap(find.text('Ikuti'));
    await tester.pumpAndSettle();
    expect(find.text('Mengikuti'), findsOneWidget);
    // Tunggu snackbar "Mengikuti ..." hilang supaya tidak menutupi tombol di layar berikutnya.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tenda Dome 4 Orang'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Jaminan yang diterima'), 300,
        scrollable: find.ancestor(of: find.text('Harga'), matching: find.byType(Scrollable)).first);
    expect(find.text('Jaminan yang diterima'), findsOneWidget);

    await tester.tap(find.text('Sewa Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Jaminan 1'), findsOneWidget);

    // Kirim tanpa isi: muncul daftar kesalahan, tidak crash.
    await tester.scrollUntilVisible(find.text('Kirim Booking'), 300,
        scrollable: find.ancestor(of: find.text('Jaminan 1'), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Kirim Booking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pilih tanggal sewa'), findsOneWidget);
    expect(find.textContaining('pilih jenis dokumen'), findsOneWidget);
  });

  testWidgets('customer searches gear across stores and reviews a finished rental', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Carrier'));
    await tester.pumpAndSettle();
    expect(find.text('Carrier 60L'), findsOneWidget);
    expect(find.text('Arjuna Outdoor'), findsNothing);

    await tester.tap(find.text('Sewa Saya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INV-DEMO-0005'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beri ulasan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4 bintang'));
    await tester.enterText(find.byType(TextField), 'Sleeping bag hangat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim ulasan'));
    await tester.pumpAndSettle();
    expect(find.text('Beri ulasan'), findsNothing);
    expect(find.text('Ulasan penyewa'), findsOneWidget);
  });

  testWidgets('provider verifies guarantee on pending order', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyedia · Arjuna'));
    await tester.pumpAndSettle();
    expect(find.text('Arjuna Outdoor'), findsOneWidget);

    await tester.tap(find.text('INV-DEMO-0001'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Valid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valid'));
    await tester.pumpAndSettle();
    expect(find.text('Terverifikasi'), findsOneWidget);

    await tester.tap(find.text('Konfirmasi booking'));
    await tester.pumpAndSettle();
    expect(find.text('Menunggu pembayaran'), findsWidgets);
  });

  testWidgets('admin dashboard and provider tabs render', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Jaminan dipegang'), findsOneWidget);
    await tester.tap(find.text('Penyedia'));
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi'), findsOneWidget);
  });

  testWidgets('admin sees customer history and can blacklist', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Denda ditinjau'), findsOneWidget);

    await tester.tap(find.text('Penyewa'));
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Bersih'), findsWidgets);

    await tester.tap(find.text('Masukkan blacklist').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tidak mengembalikan alat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(find.text('Blacklist'), findsOneWidget);
    expect(find.text('Cabut blacklist'), findsOneWidget);
  });

  testWidgets('admin dashboard lists what needs action and recent rentals', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    final pendingRow = find.text('1 penyedia menunggu verifikasi');
    final page = find.byType(Scrollable).first;
    expect(find.text('Perlu tindakan'), findsOneWidget);
    expect(pendingRow, findsOneWidget);

    await tester.scrollUntilVisible(find.text('Transaksi terbaru'), 300, scrollable: page);
    expect(find.text('Lihat semua'), findsOneWidget);

    // Baris penyedia menunggu membuka tab Penyedia.
    await tester.scrollUntilVisible(pendingRow, -300, scrollable: page);
    await tester.tap(pendingRow);
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi Penyedia'), findsOneWidget);
  });

  testWidgets('blacklisted customer cannot open the booking form', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyewa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masukkan blacklist').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tidak mengembalikan alat.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();
    const message = 'Akun Anda masuk blacklist, jadi belum bisa membuat booking baru. '
        'Alasan: Tidak mengembalikan alat. Hubungi admin untuk peninjauan.';
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.text('Arjuna Outdoor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenda Dome 4 Orang'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('Sewa Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Jaminan 1'), findsNothing);
  });

  testWidgets('stores are sorted by distance and shown on the map', (tester) async {
    await pumpApp(tester, findLocation: inLumajang);
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();

    // Semeru Camp Rent (Lumajang) lebih dekat daripada Arjuna Outdoor (Malang).
    expect(find.text('Toko diurutkan dari yang terdekat'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Semeru Camp Rent')).dy,
        lessThan(tester.getTopLeft(find.text('Arjuna Outdoor')).dy));
    expect(find.textContaining('Lumajang · '), findsOneWidget);

    await tester.tap(find.text('Peta'));
    await tester.pumpAndSettle();
    expect(find.text('Peta Toko'), findsOneWidget);
    expect(find.text('Lihat toko'), findsWidgets);
    await tester.tap(find.text('Lihat toko').first);
    await tester.pumpAndSettle();
    expect(find.text('Buka di Google Maps'), findsOneWidget);
    expect(find.textContaining('dari lokasi Anda'), findsOneWidget);
  });

  testWidgets('provider opens the store location screen', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyedia · Arjuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lokasi toko di peta'));
    await tester.pumpAndSettle();
    expect(find.text('Lokasi Toko'), findsOneWidget);
    expect(find.text('-7,93960, 112,62890'), findsOneWidget);
    // Belum digeser, jadi belum ada yang disimpan.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan lokasi')).onPressed, isNull);
  });

  testWidgets('provider replies to a review from its store page', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyedia · Arjuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Halaman toko dan ulasan'));
    await tester.pumpAndSettle();
    // Pemilik toko tidak melihat tombol ikuti.
    expect(find.text('Ikuti'), findsNothing);

    final page = find
        .ancestor(of: find.text('Buka di Google Maps'), matching: find.byType(Scrollable))
        .first;
    // Ulasan terbaru toko ini ditulis Andi Prasetyo.
    await tester.scrollUntilVisible(find.text('Andi Prasetyo'), 300, scrollable: page);
    await tester.ensureVisible(find.text('Balas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balas').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Terima kasih sudah menyewa.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(find.text('Terima kasih sudah menyewa.'), findsOneWidget);
    expect(find.text('Ubah balasan'), findsOneWidget);
  });

  testWidgets('admin reads the audit trail of its own actions', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyewa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masukkan blacklist').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tidak mengembalikan alat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jejak audit'));
    await tester.pumpAndSettle();
    expect(find.text('Jejak Audit'), findsOneWidget);
    expect(find.text('Masuk blacklist: Budi Santoso'), findsOneWidget);
    expect(find.text('Tidak mengembalikan alat'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    await tester.tap(find.text('Aksi admin'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk blacklist: Budi Santoso'), findsOneWidget);
    expect(find.text('Masuk'), findsNothing);
  });

  testWidgets('the Google button is hidden without a server and a client id', (tester) async {
    await pumpApp(tester);
    expect(find.text('Masuk dengan Google'), findsNothing);
  });

  testWidgets('AI buttons are hidden when the app runs on local data', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();
    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Saran AI'), findsNothing);
  });

  testWidgets('the store sees where to add condition photos on a paid rental', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyedia · Arjuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INV-DEMO-0003'));
    await tester.pumpAndSettle();
    expect(find.text('Foto kondisi alat'), findsOneWidget);
    expect(find.text('Saat diserahkan'), findsOneWidget);
    expect(find.text('Belum ada foto.'), findsNWidgets(2));
    // Hanya tahap serah terima yang bisa diisi sekarang.
    expect(find.text('Tambah'), findsOneWidget);
  });

  testWidgets('the store edits its fine rules and the renter sees them', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyedia · Arjuna'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aturan denda'));
    await tester.pumpAndSettle();
    expect(find.text('Aturan Denda'), findsOneWidget);
    expect(find.text('1,5 kali tarif harian'), findsOneWidget);
    // Belum ada yang diubah, jadi belum bisa disimpan.
    final save = find.widgetWithText(FilledButton, 'Simpan aturan denda');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    // Geser pengali ke paling kanan (2 kali).
    await tester.drag(find.byType(Slider).first, const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 kali tarif harian'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Keluar'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arjuna Outdoor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tenda Dome 4 Orang'));
    await tester.pumpAndSettle();
    final detail = find.ancestor(of: find.text('Harga'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Aturan denda toko'), 300, scrollable: detail);
    await tester.scrollUntilVisible(find.text('2 kali tarif harian'), 200, scrollable: detail);
    expect(find.text('2 kali tarif harian'), findsOneWidget);
  });
}
