import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:rentgear/app.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/state/app_state.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => AppState(LocalRentGearRepository.open(latency: Duration.zero)),
    child: const RentGearApp(),
  ));
}

void main() {
  testWidgets('customer opens catalog, detail and booking form', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Penyewa · Budi'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi'), findsOneWidget);

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
}
