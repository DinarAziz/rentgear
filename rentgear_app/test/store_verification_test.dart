import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rentgear/data/http_repository.dart';
import 'package:rentgear/data/local_repository.dart';
import 'package:rentgear/data/local_store.dart';
import 'package:rentgear/domain/models.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

final _photo = Uint8List.fromList([1, 2, 3]);

VerificationRequest request({String nik = '3573014101990002', List<Uint8List>? storePhotos, String name = 'Puncak Outdoor'}) =>
    VerificationRequest(
      businessName: name,
      address: 'Jl. Panglima Sudirman No. 88, Batu',
      bankAccount: 'BCA 1234567890 a.n. Agus Pratama',
      nik: nik,
      ktpPhoto: _photo,
      selfiePhoto: _photo,
      storePhotos: storePhotos ?? [_photo],
    );

void main() {
  late LocalRentGearRepository repo;
  late AppUser admin;

  setUp(() async {
    repo = LocalRentGearRepository.open(latency: Duration.zero);
    admin = await repo.login('admin@rentgear.id', 'password');
  });

  test('form dokumen diperiksa dengan pesan yang sama seperti server', () {
    expect(request().error, isNull);
    expect(request(nik: '12345').error, 'NIK harus 16 angka.');
    expect(request(nik: '3573 0141 0199 0002').error, isNull);
    expect(request(storePhotos: []).error, 'Lampirkan minimal satu foto toko atau stok alat.');
    expect(request(storePhotos: [_photo, _photo, _photo, _photo]).error, 'Foto toko paling banyak 3.');
  });

  test('toko demo Puncak sudah mengirim dokumen, dan admin melihatnya', () async {
    final puncak = await repo.provider('p-puncak');
    expect(puncak.documentsSubmitted, isTrue);
    final v = await repo.storeVerification('p-puncak', admin);
    expect(v.submitted, isTrue);
    expect(v.nikMasked, '••••••••••••0004');
    expect(v.ktpPhoto, isA<AssetPhoto>());
    expect(v.storePhotos, hasLength(1));
  });

  test('hanya pemilik toko dan admin yang melihat dokumen', () async {
    final sari = await repo.login('sari@rentgear.id', 'password');
    final budi = await repo.login('budi@rentgear.id', 'password');
    expect(() => repo.storeVerification('p-puncak', sari), throwsCode('FORBIDDEN'));
    expect(() => repo.storeVerification('p-puncak', budi), throwsCode('FORBIDDEN'));
    expect(() => repo.submitVerification('p-puncak', sari, request()), throwsCode('FORBIDDEN'));
  });

  test('menolak wajib dengan alasan, lalu pemilik toko mengirim ulang', () async {
    await expectLater(repo.setProviderStatus('p-puncak', ProviderStatus.rejected, admin), throwsCode('VALIDATION'));
    await repo.setProviderStatus('p-puncak', ProviderStatus.rejected, admin, reason: 'Foto KTP buram');

    final agus = await repo.login('agus@rentgear.id', 'password');
    final rejected = await repo.storeVerification('p-puncak', agus);
    expect(rejected.status, ProviderStatus.rejected);
    expect(rejected.rejectionReason, 'Foto KTP buram');

    final sent = await repo.submitVerification('p-puncak', agus, request(name: 'Puncak Outdoor Batu'));
    expect(sent.status, ProviderStatus.pending);
    expect(sent.rejectionReason, isNull);
    expect(sent.ktpPhoto, isA<MemoryPhoto>());
    expect((await repo.provider('p-puncak')).businessName, 'Puncak Outdoor Batu');

    await repo.setProviderStatus('p-puncak', ProviderStatus.verified, admin);
    expect((await repo.provider('p-puncak')).status, ProviderStatus.verified);
    expect(() => repo.submitVerification('p-puncak', agus, request()), throwsCode('INVALID_STATE'));
    final log = await repo.auditLog(admin);
    expect(log.map((e) => e.action), contains(AuditAction.storeDocumentsSent));
    expect(log.firstWhere((e) => e.detail?.contains('Alasan') ?? false).detail,
        'Dari Menunggu verifikasi menjadi Ditolak. Alasan: Foto KTP buram');
  });

  test('toko tanpa dokumen tidak bisa diverifikasi', () async {
    await repo.setProviderStatus('p-arjuna', ProviderStatus.pending, admin);
    expect(() => repo.setProviderStatus('p-arjuna', ProviderStatus.verified, admin), throwsCode('INVALID_STATE'));
  });

  test('admin melihat toko lain dengan NIK pemilik yang sama', () async {
    await repo.setProviderStatus('p-arjuna', ProviderStatus.rejected, admin, reason: 'Periksa ulang');
    final sari = await repo.login('sari@rentgear.id', 'password');
    final own = await repo.submitVerification('p-arjuna', sari, request(nik: '3579010101900004', name: 'Arjuna Outdoor'));
    expect(own.sameOwnerStores, isEmpty);
    expect((await repo.storeVerification('p-arjuna', admin)).sameOwnerStores, ['Puncak Outdoor']);
  });

  test('dokumen dan alasan penolakan tersimpan di HP', () async {
    final dir = await Directory.systemTemp.createTemp('rentgear_verification');
    addTearDown(() => dir.delete(recursive: true));
    var local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    var adminLocal = await local.login('admin@rentgear.id', 'password');
    await local.setProviderStatus('p-puncak', ProviderStatus.rejected, adminLocal, reason: 'Swafoto gelap');
    final agus = await local.login('agus@rentgear.id', 'password');
    await local.submitVerification('p-puncak', agus, request(storePhotos: [_photo, _photo]));
    await local.setProviderStatus('p-puncak', ProviderStatus.rejected, await local.login('admin@rentgear.id', 'password'),
        reason: 'Nama rekening beda');

    local = LocalRentGearRepository.open(store: LocalStore(dir), latency: Duration.zero);
    adminLocal = await local.login('admin@rentgear.id', 'password');
    final v = await local.storeVerification('p-puncak', adminLocal);
    expect(v.status, ProviderStatus.rejected);
    expect(v.rejectionReason, 'Nama rekening beda');
    expect(v.storePhotos, hasLength(2));
    expect((v.ktpPhoto! as MemoryPhoto).bytes, _photo);
  });

  test('buka toko hanya ada di server', () async {
    final budi = await repo.login('budi@rentgear.id', 'password');
    expect(
      () => repo.openStore(budi, const OpenStoreRequest(
          businessName: 'Budi Gear', address: 'Jl. Ijen', bankAccount: 'BCA 1', phone: '081234567801', city: 'Malang')),
      throwsCode('UNSUPPORTED'),
    );
  });

  test('versi server: dokumen dikirim multipart dan fotonya diunduh dengan token', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('t');
    final sent = <http.BaseRequest>[];
    final verification = {
      'providerId': 'p-baru',
      'status': 'pending',
      'submittedAt': '2026-10-21T10:00:00+07:00',
      'reviewedAt': null,
      'rejectionReason': null,
      'nikMasked': '••••••••••••0002',
      'ktpPhotoUrl': 'http://api.test/api/v1/files/providers/p-baru/ktp',
      'selfiePhotoUrl': 'http://api.test/api/v1/files/providers/p-baru/selfie',
      'storePhotoUrls': ['http://api.test/api/v1/files/providers/p-baru/store-0'],
      'sameOwnerStores': <String>[],
    };
    final api = HttpRentGearRepository(
      baseUrl: 'http://api.test',
      tokens: tokens,
      client: _Capture((request) {
        sent.add(request);
        if (request.url.path.contains('/files/')) return http.Response.bytes([9, 9], 200);
        return http.Response(jsonEncode({'success': true, 'data': verification}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    final user = AppUser(
        id: 'u-baru', name: 'Tania', email: 't@mail.com', phone: '0812', role: UserRole.provider, city: 'Malang', providerId: 'p-baru');
    final v = await api.submitVerification('p-baru', user, request(storePhotos: [_photo, _photo]));

    final multipart = sent.first as http.MultipartRequest;
    expect(multipart.url.path, '/api/v1/provider/verification');
    expect(multipart.fields, containsPair('nik', '3573014101990002'));
    expect(multipart.files.map((f) => f.field), ['ktpPhoto', 'selfiePhoto', 'storePhotos[0]', 'storePhotos[1]']);
    expect(sent.skip(1).every((r) => r.headers['Authorization'] == 'Bearer t'), isTrue);
    expect((v.ktpPhoto! as MemoryPhoto).bytes, [9, 9]);
    expect(v.storePhotos, hasLength(1));

    // Form yang belum lengkap tidak dikirim ke server.
    expect(() => api.submitVerification('p-baru', user, request(nik: '1')), throwsCode('VALIDATION'));
  });
}

class _Capture extends http.BaseClient {
  _Capture(this.handler);

  final http.Response Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = handler(request);
    return http.StreamedResponse(Stream.value(response.bodyBytes), response.statusCode, headers: response.headers);
  }
}
