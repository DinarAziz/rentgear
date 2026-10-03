import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rentgear/data/http_repository.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/domain/fines.dart';
import 'package:rentgear/domain/guarantee.dart';
import 'package:rentgear/domain/models.dart';
import 'package:rentgear/state/app_state.dart';

http.Response ok(Object? data) => http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response fail(String code, String message, int status) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': message},
      }),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const userJson = {
  'id': 'u-budi',
  'name': 'Budi Santoso',
  'email': 'budi@rentgear.id',
  'phone': '081234567801',
  'role': 'customer',
  'city': 'Malang',
  'providerId': null,
};

// Bentuk yang sama dengan `Present::rental` di server.
Map<String, dynamic> rentalJson({String status = 'returned'}) => {
      'id': 'r-9',
      'invoiceCode': 'INV-20261002-0001',
      'customerId': 'u-budi',
      'customerName': 'Budi Santoso',
      'providerId': 'p-semeru',
      'providerName': 'Semeru Camp Rent',
      'equipmentId': 'e-sepatu',
      'equipmentName': 'Sepatu Hiking Waterproof',
      'categoryId': 'sepatu',
      'qty': 1,
      'size': '42',
      'photoUrl': 'http://api.test/api/v1/media/equipment/sepatu_1.jpg',
      'startDate': '2026-10-03',
      'endDate': '2026-10-04',
      'pricePerDaySnapshot': 40000,
      'depositSnapshot': 100000,
      'status': status,
      'createdAt': '2026-10-02T08:00:00+07:00',
      'cancelReason': null,
      'hasPaymentProof': false,
      'returnedAt': '2026-10-06T09:30:00+07:00',
      'returnCondition': 'majorDamage',
      'lateFee': 120000,
      'damageFee': 80000,
      'damageNote': 'Sol lepas',
      'damageReview': 'pending',
      'reviewReason': 'Denda kerusakan lebih dari separuh deposit.',
      'reviewNote': null,
      'guarantees': [
        {
          'id': 'g-9',
          'type': 'ktp',
          'holderName': 'Budi Santoso',
          'maskedNumber': '••••••••••••0001',
          'hasPhoto': false,
          'status': 'held',
          'note': null,
          'heldAt': '2026-10-03T10:00:00+07:00',
          'returnedAt': null,
        },
      ],
      'logs': [
        {'from': null, 'to': 'pendingConfirmation', 'actorName': 'Budi Santoso', 'at': '2026-10-02T08:00:00+07:00', 'note': null},
        {'from': 'pickedUp', 'to': 'returned', 'actorName': 'Semeru Camp Rent', 'at': '2026-10-06T09:30:00+07:00', 'note': 'Kondisi alat: Rusak berat. Terlambat 2 hari'},
      ],
      'review': null,
    };

void main() {
  late List<http.Request> seen;
  late MemoryTokenStore tokens;

  HttpRentGearRepository repo(Future<http.Response> Function(http.Request) handler) {
    seen = [];
    return HttpRentGearRepository(
      baseUrl: 'http://api.test',
      tokens: tokens,
      client: MockClient((request) {
        seen.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() => tokens = MemoryTokenStore());

  test('login menyimpan token dan mengirimnya di permintaan berikutnya', () async {
    final api = repo((request) async => request.url.path.endsWith('/auth/login')
        ? ok({'token': 'abc123', 'user': userJson})
        : ok(<Object>[]));

    final user = await api.login('budi@rentgear.id', 'password');
    expect(user.id, 'u-budi');
    expect(user.role, UserRole.customer);
    expect(tokens.read(), 'abc123');
    expect(seen.single.headers['authorization'], isNull);

    await api.categories();
    expect(seen.last.url.toString(), 'http://api.test/api/v1/categories');
    expect(seen.last.headers['authorization'], 'Bearer abc123');
    expect(seen.last.headers['accept'], 'application/json');
  });

  test('amplop galat menjadi AppException dengan kode yang sama', () async {
    final api = repo((_) async => fail('SLOT_UNAVAILABLE', 'Stok tidak cukup pada tanggal tersebut.', 409));

    await expectLater(
      api.confirmBooking('r-1', const AppUser(id: 'u', name: 'n', email: 'e', phone: 'p', role: UserRole.provider, city: 'c')),
      throwsA(isA<AppException>()
          .having((e) => e.code, 'code', 'SLOT_UNAVAILABLE')
          .having((e) => e.message, 'message', 'Stok tidak cukup pada tanggal tersebut.')),
    );
  });

  test('server mati atau jawaban bukan JSON menjadi galat NETWORK', () async {
    var api = repo((_) async => throw const SocketException('Connection refused'));
    await expectLater(api.categories(), throwsA(isA<AppException>().having((e) => e.code, 'code', 'NETWORK')));

    api = repo((_) async => http.Response('<html>502 Bad Gateway</html>', 502));
    await expectLater(api.categories(), throwsA(isA<AppException>().having((e) => e.code, 'code', 'NETWORK')));
  });

  test('sesi dipulihkan dari token, dan token yang ditolak dibuang', () async {
    tokens.write('lama');
    var api = repo((_) async => ok(userJson));
    expect((await api.restoreSession())?.name, 'Budi Santoso');
    expect(seen.single.url.path, '/api/v1/auth/me');

    api = repo((_) async => fail('UNAUTHENTICATED', 'Sesi berakhir. Silakan masuk lagi.', 401));
    expect(await api.restoreSession(), isNull);
    expect(tokens.read(), isNull);

    // Tanpa token tidak ada permintaan sama sekali.
    api = repo((_) async => ok(userJson));
    expect(await api.restoreSession(), isNull);
    expect(seen, isEmpty);
  });

  test('JSON transaksi dipetakan ke model, termasuk denda dan jaminan tersamar', () async {
    tokens.write('t');
    final api = repo((_) async => ok(rentalJson()));

    final r = await api.rental('r-9');
    expect(r.status, RentalStatus.returned);
    expect(r.size, '42');
    expect(r.startDate, DateTime(2026, 10, 3));
    expect(r.endDate, DateTime(2026, 10, 4));
    expect(r.durationDays, 2);
    expect(r.grandTotal, 40000 * 2 + 100000);
    expect(r.photo, isA<NetworkPhoto>().having((p) => p.url, 'url', contains('/media/equipment/sepatu_1.jpg')));

    expect(r.returnCondition, ReturnCondition.majorDamage);
    expect(r.lateFee, 120000);
    expect(r.damageFee, 80000);
    expect(r.damageReview, DamageReview.pending);
    expect(r.fineShortfall, 100000);
    expect(r.returnedAt, isNotNull);

    final g = r.guarantees.single;
    expect(g.type, GuaranteeType.ktp);
    expect(g.status, GuaranteeStatus.held);
    expect(g.maskedNumber, '••••••••••••0001');
    expect(g.photo, isNull);
    expect(r.logs.map((l) => l.to), [RentalStatus.pendingConfirmation, RentalStatus.returned]);
    expect(r.logs.last.note, contains('Terlambat 2 hari'));
    // Tanpa foto jaminan dan bukti transfer, tidak ada unduhan tambahan.
    expect(seen.length, 1);
  });

  test('detail transaksi mengunduh foto jaminan dan bukti transfer', () async {
    tokens.write('t');
    final json = rentalJson(status: 'paid')
      ..['hasPaymentProof'] = true
      ..['guarantees'] = [
        {...(rentalJson()['guarantees'] as List).first as Map<String, dynamic>, 'hasPhoto': true},
      ];
    final api = repo((request) async {
      final path = request.url.path;
      if (path.endsWith('/files/guarantees/g-9')) return http.Response.bytes([1, 2, 3], 200);
      if (path.endsWith('/files/payments/r-9')) return http.Response.bytes([9, 9], 200);
      return ok(json);
    });

    final r = await api.rental('r-9');
    expect(r.guarantees.single.photo, [1, 2, 3]);
    expect(r.paymentProof, [9, 9]);
    expect(seen.every((q) => q.headers['authorization'] == 'Bearer t'), isTrue);
  });

  test('terima pengembalian mengirim kondisi dan denda kerusakan', () async {
    tokens.write('t');
    final api = repo((_) async => ok(rentalJson()));
    const dewi = AppUser(id: 'u-dewi', name: 'Dewi', email: 'e', phone: 'p', role: UserRole.provider, city: 'c', providerId: 'p-semeru');

    await api.receiveReturn('r-9', dewi, condition: ReturnCondition.majorDamage, damageFee: 80000, damageNote: 'Sol lepas');

    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/api/v1/rentals/r-9/return');
    expect(jsonDecode(seen.single.body), {'condition': 'majorDamage', 'damageFee': 80000.0, 'damageNote': 'Sol lepas'});
  });

  test('ketersediaan memakai tanggal kalender tanpa jam', () async {
    tokens.write('t');
    final api = repo((_) async => ok({
          'available': 8,
          'sizes': {'42': 2, '43': 0},
        }));

    expect(await api.availableQty('e-sepatu', DateTime(2026, 10, 3, 15, 30), DateTime(2026, 10, 4)), 8);
    expect(seen.last.url.queryParameters, {'start': '2026-10-03', 'end': '2026-10-04'});
    expect(await api.sizeAvailability('e-sepatu', DateTime(2026, 10, 3), DateTime(2026, 10, 4)), {'42': 2, '43': 0});
  });

  test('booking dikirim sebagai multipart dengan Idempotency-Key', () async {
    tokens.write('t');
    late http.BaseRequest sent;
    final api = HttpRentGearRepository(
      baseUrl: 'http://api.test',
      tokens: tokens,
      client: _Capture((request) {
        sent = request;
        return ok(rentalJson(status: 'pendingConfirmation'));
      }),
    );

    final r = await api.createBooking(BookingRequest(
      customerId: 'u-budi',
      equipmentId: 'e-sepatu',
      qty: 1,
      size: '42',
      startDate: DateTime(2026, 10, 3),
      endDate: DateTime(2026, 10, 4),
      idempotencyKey: 'kunci-1',
      guarantees: [
        GuaranteeDraft(type: GuaranteeType.ktp, holderName: 'Budi Santoso', documentNumber: '3573011204020001')
          ..photo = Uint8List.fromList([1, 2, 3]),
      ],
    ));

    expect(r.status, RentalStatus.pendingConfirmation);
    final multipart = sent as http.MultipartRequest;
    expect(multipart.headers['Idempotency-Key'], 'kunci-1');
    expect(multipart.headers['Authorization'], 'Bearer t');
    expect(multipart.fields, containsPair('startDate', '2026-10-03'));
    expect(multipart.fields, containsPair('guarantees[0][type]', 'ktp'));
    expect(multipart.fields, containsPair('guarantees[0][documentNumber]', '3573011204020001'));
    expect(multipart.fields.keys, isNot(contains('customerId')));
    expect(multipart.files.single.field, 'guarantees[0][photo]');
  });

  test('mode server memuat ulang layar saat aplikasi kembali ke depan', () async {
    final remote = AppState(repo((_) async => ok(<Object>[])));
    final local = AppState(LocalRentGearRepository.open(latency: Duration.zero));

    // Pemanggilan pertama di mode lokal menjalankan job otomatis data demo.
    await local.refresh();
    final before = local.revision;

    await remote.refresh();
    await local.refresh();

    // Data server bisa berubah dari perangkat lain; data lokal tidak.
    expect(remote.revision, 1);
    expect(local.revision, before);
  });

  test('toko dipetakan dengan rating, pengikut, lokasi, dan aturan jaminan', () async {
    tokens.write('t');
    final api = repo((_) async => ok({
          'id': 'p-semeru',
          'ownerId': 'u-dewi',
          'businessName': 'Semeru Camp Rent',
          'city': 'Lumajang',
          'address': 'Jl. Raya Senduro No. 5, Lumajang',
          'status': 'verified',
          'latitude': -8.1049,
          'longitude': 113.0868,
          'bankAccount': 'BRI 0012',
          'policy': {
            'acceptedTypes': ['ktp', 'ktm'],
            'baseRequired': 1,
            'highValueThreshold': 750000,
            'highValueRequired': 2,
          },
          'rating': 4.6667,
          'reviewCount': 3,
          'followerCount': 2,
        }));

    final p = await api.provider('p-semeru');
    expect(p.status, ProviderStatus.verified);
    expect(p.rating, closeTo(4.667, 0.001));
    expect(p.reviewCount, 3);
    expect(p.followerCount, 2);
    expect(p.latitude, -8.1049);
    expect(p.policy.acceptedTypes, {GuaranteeType.ktp, GuaranteeType.ktm});
    expect(p.policy.highValueThreshold, 750000);
  });
}

/// MockClient hanya mengenal permintaan biasa; ini menangkap multipart juga.
class _Capture extends http.BaseClient {
  _Capture(this.handler);

  final http.Response Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
