import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentgear/widgets/common.dart';

void main() {
  testWidgets('askReason disables Kirim until a reason is typed', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askReason(context, title: 'Tolak KTP'),
          child: const Text('buka'),
        ),
      ),
    ));

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    FilledButton kirim() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Kirim'));
    expect(kirim().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(kirim().onPressed, isNull);

    await tester.enterText(find.byType(TextField), ' Foto buram ');
    await tester.pump();
    expect(kirim().onPressed, isNotNull);

    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(result, 'Foto buram');
  });
}
