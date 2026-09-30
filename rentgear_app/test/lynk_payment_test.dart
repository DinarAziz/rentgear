import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/features/rental/rental_detail_screen.dart';
import 'package:rentgear/state/app_state.dart';

void main() {
  testWidgets(
    'customer awaiting payment sees Lynk.id steps and can copy the invoice code',
    (tester) async {
      await initializeDateFormatting('id_ID');
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final state = AppState(
        LocalRentGearRepository.open(latency: Duration.zero),
      );
      await state.login(
        'rina@rentgear.id',
        LocalRentGearRepository.demoPassword,
      );

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: RentalDetailScreen(rentalId: 'r-2')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cara bayar'), findsOneWidget);
      expect(find.text('INV-DEMO-0002'), findsWidgets);
      expect(find.text('Buka Lynk.id'), findsOneWidget);

      // Taruh ikon salin di tengah layar supaya tidak tertutup bar aksi.
      final copyInvoice = find.byTooltip('Salin Kode invoice');
      Scrollable.ensureVisible(tester.element(copyInvoice), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(copyInvoice);
      await tester.pump();
      expect(find.text('Kode invoice disalin.'), findsOneWidget);
      expect(copied, 'INV-DEMO-0002');
    },
  );
}
