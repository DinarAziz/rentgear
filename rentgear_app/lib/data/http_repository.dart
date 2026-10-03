import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fines.dart';
import '../domain/guarantee.dart';
import '../domain/models.dart';
import 'api_codec.dart';
import 'repository.dart';

/// Tempat menyimpan token login supaya sesi bertahan setelah aplikasi ditutup.
abstract class TokenStore {
  String? read();
  Future<void> write(String? token);
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  String? read() => _token;

  @override
  Future<void> write(String? token) async => _token = token;
}

class PrefsTokenStore implements TokenStore {
  PrefsTokenStore._(this._prefs);

  static const _key = 'rentgear_api_token';
  final SharedPreferences _prefs;

  static Future<PrefsTokenStore> open() async =>
      PrefsTokenStore._(await SharedPreferences.getInstance());

  @override
  String? read() => _prefs.getString(_key);

  @override
  Future<void> write(String? token) async =>
      token == null ? await _prefs.remove(_key) : await _prefs.setString(_key, token);
}

/// Repository yang memakai server Laravel (`rentgear_api/`, REST `/api/v1`).
/// Aturan bisnis dijalankan server; kelas ini hanya mengirim permintaan dan
/// memetakan jawabannya ke objek domain.
class HttpRentGearRepository implements RentGearRepository {
  HttpRentGearRepository({required String baseUrl, required this._tokens, http.Client? client})
      : _base = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/'),
        _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 20);
  static const _offline = AppException(
      'NETWORK', 'Tidak bisa terhubung ke server. Periksa jaringan, lalu coba lagi.');

  final Uri _base;
  final TokenStore _tokens;
  final http.Client _client;

  @override
  bool get isRemote => true;

  // ---------------------------------------------------------------- transport

  Uri _uri(String path, [Map<String, String>? query]) =>
      _base.resolve(path).replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_tokens.read() case final token?) 'Authorization': 'Bearer $token',
      };

  /// Kirim permintaan dan ubah kegagalan jaringan menjadi [AppException].
  Future<http.Response> _run(Future<http.Response> Function() send) async {
    try {
      return await send().timeout(_timeout);
    } on AppException {
      rethrow;
    } catch (_) {
      // Server mati, tidak ada jaringan, atau waktu habis.
      throw _offline;
    }
  }

  /// Membuka amplop `{success, data}`; amplop galat menjadi [AppException]
  /// dengan kode yang sama seperti repository lokal.
  Object? _unwrap(http.Response response) {
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw _offline; // mis. halaman galat dari proxy, bukan dari aplikasi
    }
    if (body is! Map<String, dynamic>) throw _offline;
    if (body['success'] == true) return body['data'];
    final error = body['error'] as Map<String, dynamic>?;
    throw AppException(
      error?['code'] as String? ?? 'SERVER',
      error?['message'] as String? ?? 'Server mengalami gangguan (${response.statusCode}).',
    );
  }

  Future<Object?> _get(String path, [Map<String, String>? query]) async =>
      _unwrap(await _run(() => _client.get(_uri(path, query), headers: _headers)));

  Future<Object?> _dispatch(http.BaseRequest request) async =>
      _unwrap(await _run(() async => http.Response.fromStream(await _client.send(request))));

  Future<Object?> _send(String method, String path, [Map<String, Object?>? body]) async {
    final request = http.Request(method, _uri(path))..headers.addAll(_headers);
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    return _dispatch(request);
  }

  Future<Object?> _multipart(
    String path, {
    required Map<String, String> fields,
    required Map<String, Uint8List> files,
    Map<String, String> headers = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll({..._headers, ...headers})
      ..fields.addAll(fields);
    for (final file in files.entries) {
      request.files.add(http.MultipartFile.fromBytes(file.key, file.value, filename: 'foto.jpg'));
    }
    return _dispatch(request);
  }

  /// Berkas privat (foto jaminan, bukti transfer). `null` bila tidak ada.
  Future<Uint8List?> _file(String path) async {
    final response = await _run(() => _client.get(_uri(path), headers: _headers));
    return response.statusCode == 200 ? response.bodyBytes : null;
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<T> _list<T>(Object? data, T Function(Map<String, dynamic>) convert) =>
      [for (final item in data as List) convert(item as Map<String, dynamic>)];

  Rental _rental(Object? data) => ApiCodec.rental(data as Map<String, dynamic>);

  Equipment _equipment(Object? data) => ApiCodec.equipment(data as Map<String, dynamic>);

  ProviderProfile _provider(Object? data) => ApiCodec.provider(data as Map<String, dynamic>);

  Future<Rental> _action(String rentalId, String action, [Map<String, Object?>? body]) async =>
      _rental(await _send('POST', 'rentals/$rentalId/$action', body));

  // ---------------------------------------------------------------- sesi

  @override
  Future<AppUser> login(String email, String password) =>
      _startSession('auth/login', {'email': email, 'password': password});

  @override
  Future<AppUser> loginWithGoogle(String idToken) => _startSession('auth/google', {'idToken': idToken});

  Future<AppUser> _startSession(String path, Map<String, dynamic> body) async {
    await _tokens.write(null);
    final data = await _send('POST', path, body) as Map<String, dynamic>;
    await _tokens.write(data['token'] as String);
    return ApiCodec.user(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser?> restoreSession() async {
    if (_tokens.read() == null) return null;
    try {
      return ApiCodec.user(await _get('auth/me') as Map<String, dynamic>);
    } on AppException catch (e) {
      // Token ditolak server: buang. Server tidak terjangkau: token disimpan
      // untuk dicoba lagi nanti, tetapi pengguna tetap harus login sekarang.
      if (e.code != 'NETWORK') await _tokens.write(null);
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _send('POST', 'auth/logout');
    } on AppException {
      // Keluar tetap berhasil di perangkat walau server tidak terjangkau.
    }
    await _tokens.write(null);
  }

  /// Di server, perubahan status otomatis dijalankan scheduler.
  @override
  Future<int> runScheduledJobs() async => 0;

  // ---------------------------------------------------------------- katalog

  @override
  Future<List<Category>> categories() async => _list(
      await _get('categories'), (j) => Category(j['id'] as String, j['name'] as String));

  @override
  Future<List<Equipment>> searchEquipment({String query = '', String? categoryId}) async => _list(
        await _get('equipment', {
          if (query.trim().isNotEmpty) 'query': query.trim(),
          'categoryId': ?categoryId,
        }),
        ApiCodec.equipment,
      );

  @override
  Future<List<Equipment>> providerEquipment(String providerId) async =>
      _list(await _get('providers/$providerId/equipment'), ApiCodec.equipment);

  @override
  Future<Equipment> equipment(String id) async => _equipment(await _get('equipment/$id'));

  @override
  Future<ProviderProfile> provider(String id) async => _provider(await _get('providers/$id'));

  @override
  Future<List<ProviderProfile>> providers() async => _list(await _get('providers'), ApiCodec.provider);

  Future<Map<String, dynamic>> _availability(String id, DateTime start, DateTime end, [String? size]) async =>
      await _get('equipment/$id/availability', {'start': _day(start), 'end': _day(end), 'size': ?size})
          as Map<String, dynamic>;

  @override
  Future<int> availableQty(String equipmentId, DateTime start, DateTime end, {String? size}) async =>
      (await _availability(equipmentId, start, end, size))['available'] as int;

  @override
  Future<Map<String, int>> sizeAvailability(String equipmentId, DateTime start, DateTime end) async =>
      ((await _availability(equipmentId, start, end))['sizes'] as Map).cast<String, int>();

  @override
  Future<Equipment> saveEquipment(Equipment draft, AppUser actor) async {
    final files = <String, Uint8List>{};
    final fields = <String, String>{
      'categoryId': draft.categoryId,
      'name': draft.name,
      'brand': draft.brand,
      'description': draft.description,
      'pricePerDay': '${draft.pricePerDay}',
      'depositAmount': '${draft.depositAmount}',
      'weightGram': '${draft.weightGram}',
      'stock': '${draft.stock}',
      if (draft.capacityPerson case final capacity?) 'capacityPerson': '$capacity',
      'isActive': draft.isActive ? '1' : '0',
      for (final (i, s) in draft.sizes.indexed) ...{
        'sizes[$i][label]': s.label,
        'sizes[$i][stock]': '${s.stock}',
      },
    };
    // Urutan foto: "keep:<id>" untuk foto yang sudah ada di server,
    // "new:<n>" untuk foto baru yang ikut diunggah.
    for (final (i, photo) in draft.photos.indexed) {
      switch (photo) {
        case NetworkPhoto(:final id):
          fields['photoOrder[$i]'] = 'keep:$id';
        case MemoryPhoto(:final bytes):
          fields['photoOrder[$i]'] = 'new:${files.length}';
          files['newPhotos[${files.length}]'] = bytes;
        case AssetPhoto():
          break; // foto bawaan aplikasi tidak ada di mode server
      }
    }
    final path = draft.id.isEmpty ? 'equipment' : 'equipment/${draft.id}';
    return _equipment(await _multipart(path, fields: fields, files: files));
  }

  // ---------------------------------------------------------------- booking

  @override
  Future<Rental> createBooking(BookingRequest request) async {
    final files = <String, Uint8List>{};
    final fields = <String, String>{
      'equipmentId': request.equipmentId,
      'qty': '${request.qty}',
      'size': ?request.size,
      'startDate': _day(request.startDate),
      'endDate': _day(request.endDate),
    };
    for (final (i, g) in request.guarantees.indexed) {
      fields['guarantees[$i][type]'] = g.type?.name ?? '';
      fields['guarantees[$i][holderName]'] = g.holderName;
      fields['guarantees[$i][documentNumber]'] = g.documentNumber;
      if (g.photo case final photo?) files['guarantees[$i][photo]'] = photo;
    }
    return _rental(await _multipart('rentals',
        fields: fields, files: files, headers: {'Idempotency-Key': request.idempotencyKey}));
  }

  /// Detail transaksi ikut mengunduh foto jaminan dan bukti transfer, karena
  /// layar detail menampilkannya. Daftar transaksi tidak.
  @override
  Future<Rental> rental(String id) async {
    final json = await _get('rentals/$id') as Map<String, dynamic>;
    final rental = ApiCodec.rental(json);
    final guarantees = (json['guarantees'] as List).cast<Map<String, dynamic>>();
    final photos = await Future.wait([
      for (final g in guarantees)
        g['hasPhoto'] == true ? _file('files/guarantees/${g['id']}') : Future.value(null),
    ]);
    if (photos.any((p) => p != null)) {
      // `Guarantee.photo` final, jadi jaminan disusun ulang bersama fotonya.
      final withPhotos = [
        for (final (i, g) in rental.guarantees.indexed)
          Guarantee(
            id: g.id,
            type: g.type,
            holderName: g.holderName,
            documentNumber: g.documentNumber,
            photo: photos[i],
            status: g.status,
            note: g.note,
          )
            ..heldAt = g.heldAt
            ..returnedAt = g.returnedAt,
      ];
      rental.guarantees
        ..clear()
        ..addAll(withPhotos);
    }
    if (json['hasPaymentProof'] == true) {
      rental.paymentProof = await _file('files/payments/$id');
    }
    return rental;
  }

  Future<List<Rental>> _rentals() async => _list(await _get('rentals'), ApiCodec.rental);

  // Server memilih daftar berdasarkan peran pemilik token, jadi id di sini tidak dikirim.
  @override
  Future<List<Rental>> customerRentals(String customerId) => _rentals();

  @override
  Future<List<Rental>> providerRentals(String providerId) => _rentals();

  @override
  Future<List<Rental>> allRentals() => _rentals();

  // ---------------------------------------------------------------- alur sewa

  @override
  Future<Rental> reviewGuarantee(String rentalId, String guaranteeId, AppUser actor,
          {required bool accept, String? note}) =>
      _action(rentalId, 'guarantees/$guaranteeId/review', {'accept': accept, 'note': note});

  @override
  Future<Rental> confirmBooking(String rentalId, AppUser actor) => _action(rentalId, 'confirm');

  @override
  Future<Rental> rejectBooking(String rentalId, AppUser actor, String reason) =>
      _action(rentalId, 'reject', {'reason': reason});

  @override
  Future<Rental> cancelBooking(String rentalId, AppUser actor, String reason) =>
      _action(rentalId, 'cancel', {'reason': reason});

  @override
  Future<Rental> submitPayment(String rentalId, AppUser actor, Uint8List proof) async =>
      _rental(await _multipart('rentals/$rentalId/payment', fields: const {}, files: {'proof': proof}));

  @override
  Future<Rental> handover(String rentalId, AppUser actor) => _action(rentalId, 'handover');

  @override
  Future<Rental> receiveReturn(String rentalId, AppUser actor,
          {ReturnCondition condition = ReturnCondition.good, double damageFee = 0, String? damageNote}) =>
      _action(rentalId, 'return',
          {'condition': condition.name, 'damageFee': damageFee, 'damageNote': damageNote});

  @override
  Future<Rental> objectToDamageFee(String rentalId, AppUser actor, String reason) =>
      _action(rentalId, 'damage-objection', {'reason': reason});

  @override
  Future<Rental> decideDamageFee(String rentalId, AppUser actor, {required double amount, String? note}) =>
      _action(rentalId, 'damage-decision', {'amount': amount, 'note': note});

  @override
  Future<Rental> returnGuaranteesAndComplete(String rentalId, AppUser actor) =>
      _action(rentalId, 'complete');

  // ---------------------------------------------------------------- toko & admin

  @override
  Future<ProviderProfile> updateGuaranteePolicy(
          String providerId, GuaranteePolicy policy, AppUser actor) async =>
      _provider(await _send('PUT', 'provider/guarantee-policy', ApiCodec.policyToJson(policy)));

  @override
  Future<ProviderProfile> updateProviderLocation(String providerId, AppUser actor,
          {required double latitude, required double longitude}) async =>
      _provider(await _send('PUT', 'provider/location', {'latitude': latitude, 'longitude': longitude}));

  @override
  Future<ProviderProfile> setProviderStatus(
          String providerId, ProviderStatus status, AppUser actor) async =>
      _provider(await _send('PUT', 'providers/$providerId/status', {'status': status.name}));

  @override
  Future<List<Review>> providerReviews(String providerId) async =>
      _list(await _get('providers/$providerId/reviews'), ApiCodec.review);

  @override
  Future<Review> replyToReview(String reviewId, AppUser actor, String reply) async =>
      ApiCodec.review(await _send('PUT', 'reviews/$reviewId/reply', {'reply': reply}) as Map<String, dynamic>);

  @override
  Future<Rental> submitReview(String rentalId, AppUser actor, {required int rating, String comment = ''}) =>
      _action(rentalId, 'review', {'rating': rating, 'comment': comment});

  @override
  Future<Set<String>> followedProviders(String customerId) async =>
      {...(await _get('me/follows') as List).cast<String>()};

  @override
  Future<ProviderProfile> setFollow(String providerId, AppUser actor, {required bool follow}) async =>
      _provider(await _send(follow ? 'PUT' : 'DELETE', 'providers/$providerId/follow'));

  @override
  Future<List<CustomerRecord>> customers(AppUser actor) async =>
      _list(await _get('customers'), ApiCodec.customerRecord);

  /// Server hanya memberi tahu status blacklist pemilik token.
  @override
  Future<BlacklistEntry?> blacklistOf(String userId) async =>
      ApiCodec.blacklist(await _get('me/blacklist') as Map<String, dynamic>?);

  @override
  Future<void> setBlacklist(String customerId, AppUser actor, {required bool blocked, String? reason}) =>
      _send(blocked ? 'PUT' : 'DELETE', 'customers/$customerId/blacklist',
          blocked ? {'reason': reason} : null);

  @override
  Future<List<AuditEntry>> auditLog(AppUser actor) async => _list(await _get('audit'), ApiCodec.audit);
}
