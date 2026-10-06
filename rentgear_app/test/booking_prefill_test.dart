import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:rentgear/core/format.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/domain/availability.dart';
import 'package:rentgear/features/customer/booking_screen.dart';
import 'package:rentgear/features/customer/equipment_detail_screen.dart';
import 'package:rentgear/state/app_state.dart';

void main() {
  late AppState state;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await initializeDateFormatting('id_ID');
    state = AppState(LocalRentGearRepository.open(latency: Duration.zero));
    await state.login('budi@rentgear.id', LocalRentGearRepository.demoPassword);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: MaterialApp(home: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets('dari saran AI, form sewa sudah berisi jumlah unit dan lama sewa mulai besok', (tester) async {
    await pump(
      tester,
      const EquipmentDetailScreen(equipmentId: 'e-sbpolar', prefill: BookingPrefill(qty: 3, days: 2)),
    );
    await tester.ensureVisible(find.text('Sewa Sekarang'));
    await tester.tap(find.text('Sewa Sekarang'));
    await tester.pumpAndSettle();

    final start = dateOnly(DateTime.now()).add(const Duration(days: 1));
    final end = start.add(const Duration(days: 1));
    expect(find.textContaining('Diisi dari saran AI: 3 unit selama 2 hari'), findsOneWidget);
    expect(find.text('${rentangTanggal(start, end)} (2 hari)'), findsOneWidget);
    expect(find.textContaining('× 3 unit × 2 hari'), findsOneWidget);
    expect(find.text('Pilih tanggal'), findsNothing);
  });

  testWidgets('jumlah dari saran AI diturunkan ke stok yang tersisa', (tester) async {
    // Kompor Arjuna: stok 4.
    await pump(
      tester,
      const EquipmentDetailScreen(equipmentId: 'e-kompor', prefill: BookingPrefill(qty: 9, days: 1)),
    );
    await tester.ensureVisible(find.text('Sewa Sekarang'));
    await tester.tap(find.text('Sewa Sekarang'));
    await tester.pumpAndSettle();

    expect(find.textContaining('× 9 unit'), findsNothing);
    expect(find.textContaining(RegExp(r'× [1-4] unit × 1 hari')), findsOneWidget);
  });

  testWidgets('dari katalog biasa, form sewa tetap kosong', (tester) async {
    await pump(tester, const EquipmentDetailScreen(equipmentId: 'e-sbpolar'));
    await tester.ensureVisible(find.text('Sewa Sekarang'));
    await tester.tap(find.text('Sewa Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih tanggal'), findsOneWidget);
    expect(find.textContaining('Diisi dari saran AI'), findsNothing);
  });
}
