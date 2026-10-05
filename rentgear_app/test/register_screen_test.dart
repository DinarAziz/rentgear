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

  Future<void> pumpRemoteApp(WidgetTester tester) async {
    // Cukup tinggi supaya seluruh formulir penyedia terlihat tanpa menggulir.
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    seen = [];
    final repo = HttpRentGearRepository(
      baseUrl: 'http://api.test',
      tokens: MemoryTokenStore(),
      client: MockClient((request) async {
        seen.add(request);
        return json({
          'success': false,
          'error': {'code': 'VALIDATION', 'message': 'Email sudah terdaftar. Silakan masuk.'},
        }, 422);
      }),
    );
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AppState(repo), child: const RentGearApp()));
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('mode data lokal tidak menawarkan daftar akun', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(LocalRentGearRepository.open(latency: Duration.zero)),
      child: const RentGearApp(),
    ));
    expect(find.text('Belum punya akun? Daftar'), findsNothing);
  });

  testWidgets('isian yang salah ditahan di formulir sebelum dikirim', (tester) async {
    await pumpRemoteApp(tester);
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Data toko'), findsNothing);

    await fill(tester, 'Email', 'tania');
    await fill(tester, 'Nomor HP', '0812-abc');
    await fill(tester, 'Password', '1234567');
    await submit(tester);

    expect(find.text('Wajib diisi.'), findsNWidgets(2));
    expect(find.text('Isi email yang benar, misalnya nama@mail.com.'), findsOneWidget);
    expect(find.text('Isi 9 sampai 15 angka, misalnya 081234567890.'), findsOneWidget);
    expect(find.text('Password minimal 8 karakter.'), findsOneWidget);
    expect(seen, isEmpty);
  });

  testWidgets('penyedia mengisi data toko, dan penolakan server tampil di layar', (tester) async {
    await pumpRemoteApp(tester);
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penyedia'));
    await tester.pumpAndSettle();
    expect(find.text('Data toko'), findsOneWidget);

    await fill(tester, 'Nama lengkap', 'Tania Putri');
    await fill(tester, 'Email', ' Tania@Mail.com ');
    await fill(tester, 'Nomor HP', '081298765432');
    await fill(tester, 'Kota', 'Malang');
    await fill(tester, 'Password', 'rahasia123');
    await fill(tester, 'Nama toko', 'Bromo Gear');
    await fill(tester, 'Alamat toko', 'Jl. Ijen No. 3');
    await fill(tester, 'Rekening tujuan transfer', 'BCA 123 a.n. Tania');
    await submit(tester);

    final sent = jsonDecode(seen.single.body) as Map<String, dynamic>;
    expect(seen.single.url.path, '/api/v1/auth/register');
    expect(sent, containsPair('role', 'provider'));
    expect(sent, containsPair('email', 'tania@mail.com'));
    expect(sent, containsPair('businessName', 'Bromo Gear'));
    await tester.ensureVisible(find.text('Email sudah terdaftar. Silakan masuk.'));
    expect(find.text('Daftar Akun'), findsOneWidget);
  });
}
