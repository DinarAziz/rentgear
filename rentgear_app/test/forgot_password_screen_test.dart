import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:rentgear/app.dart';
import 'package:rentgear/data/http_repository.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/state/app_state.dart';

http.Response json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> seen;

  /// Server tiruan: kode yang benar hanya `123456`.
  Future<void> pumpRemoteApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    seen = [];
    final repo = HttpRentGearRepository(
      baseUrl: 'http://api.test',
      tokens: MemoryTokenStore(),
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/auth/forgot-password')) {
          return json({'success': true, 'data': null}, 200);
        }
        return json({
          'success': false,
          'error': {'code': 'RESET_CODE_INVALID', 'message': 'Kode salah atau sudah kedaluwarsa.'},
        }, 422);
      }),
    );
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AppState(repo), child: const RentGearApp()));
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  Future<void> press(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('mode data lokal tidak menawarkan lupa password', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(LocalRentGearRepository.open(latency: Duration.zero)),
      child: const RentGearApp(),
    ));
    expect(find.text('Lupa password?'), findsNothing);
  });

  testWidgets('email dari layar masuk terbawa, dan email yang salah ditahan', (tester) async {
    await pumpRemoteApp(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'tania');
    await press(tester, 'Lupa password?');
    expect(find.widgetWithText(TextFormField, 'tania'), findsOneWidget);

    await press(tester, 'Kirim kode');
    expect(find.text('Isi email yang benar, misalnya nama@mail.com.'), findsOneWidget);
    expect(find.text('Kode dari email'), findsNothing);
    expect(seen, isEmpty);
  });

  testWidgets('kode diminta, isian diperiksa, lalu penolakan server tampil di layar', (tester) async {
    await pumpRemoteApp(tester);
    await press(tester, 'Lupa password?');
    await fill(tester, 'Email', ' Tania@Mail.com ');
    await press(tester, 'Kirim kode');

    expect(seen.single.url.path, '/api/v1/auth/forgot-password');
    expect(jsonDecode(seen.single.body), {'email': 'tania@mail.com'});
    expect(find.textContaining('Jika tania@mail.com terdaftar'), findsOneWidget);

    await fill(tester, 'Kode dari email', '12345');
    await fill(tester, 'Password baru', '1234567');
    await press(tester, 'Simpan password baru');
    expect(find.text('Isi 6 angka dari email.'), findsOneWidget);
    expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    expect(seen, hasLength(1));

    await fill(tester, 'Kode dari email', '654321');
    await fill(tester, 'Password baru', 'rahasiabaru1');
    await press(tester, 'Simpan password baru');
    expect(seen.last.url.path, '/api/v1/auth/reset-password');
    expect(jsonDecode(seen.last.body), {'email': 'tania@mail.com', 'code': '654321', 'password': 'rahasiabaru1'});
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(find.text('Lupa Password'), findsOneWidget);

    await press(tester, 'Kirim ulang kode');
    expect(seen.last.url.path, '/api/v1/auth/forgot-password');
    expect(find.text('Kode baru dikirim. Kode lama tidak berlaku lagi.'), findsOneWidget);
  });
}
