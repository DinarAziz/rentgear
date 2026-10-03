import 'dart:typed_data';

import '../domain/availability.dart';
import '../domain/equipment_rules.dart';
import '../domain/fines.dart';
import '../domain/guarantee.dart';
import '../domain/models.dart';
import '../domain/rental_state_machine.dart';
import 'local_codec.dart';
import 'local_store.dart';
import 'repository.dart';
import 'seed.dart';

/// Repository lokal: aplikasi Android berjalan mandiri tanpa server.
/// Data awal dari [SeedData], perubahan disimpan ke [LocalStore] (memori HP).
/// Aturan bisnis (ALG-2, state machine, aturan jaminan, hak akses) dijalankan
/// di sini dengan perilaku yang sama seperti server Laravel nanti.
class LocalRentGearRepository implements RentGearRepository {
  LocalRentGearRepository._(SeedData seed, this._store, this.latency)
      : _users = seed.users,
        _categories = seed.categories,
        _equipment = List.of(seed.equipment),
        _providers = seed.providers(),
        _rentals = seed.rentals(),
        _reviews = seed.reviews(),
        _follows = seed.follows();

  /// [store] `null` = hanya di memori (dipakai unit test).
  factory LocalRentGearRepository.open({
    LocalStore? store,
    DateTime? now,
    Duration latency = const Duration(milliseconds: 250),
  }) {
    final repo = LocalRentGearRepository._(SeedData(now ?? DateTime.now()), store, latency);
    final saved = store?.read();
    if (saved != null) repo._restore(saved);
    repo._refreshStoreStats();
    return repo;
  }

  static const demoPassword = 'password';

  @override
  bool get isRemote => false;
  static const _schemaVersion = 3;

  /// Versi 2 belum punya denda dan blacklist; sisanya sama, jadi tetap dibaca.
  static const _readableVersions = {2, 3};

  final LocalStore? _store;
  final Duration latency;
  final List<AppUser> _users;
  final List<Category> _categories;
  List<Equipment> _equipment;
  List<ProviderProfile> _providers;
  List<Rental> _rentals;
  List<Review> _reviews;

  /// Id penyewa -> id toko yang diikutinya.
  Map<String, Set<String>> _follows;
  final Map<String, String> _idempotency = {};
  final Map<String, BlacklistEntry> _blacklist = {};

  /// Jumlah pelanggaran tiap penyewa saat admin terakhir mencabut blacklist-nya.
  final Map<String, int> _violationBaseline = {};
  int _sequence = 0;
  String? _sessionUserId;

  Future<T> _delay<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return body();
  }

  /// Seperti [_delay], lalu menyimpan seluruh data ke HP.
  Future<T> _mutate<T>(T Function() body) => _delay(() {
        final result = body();
        _save();
        return result;
      });

  // ---------------------------------------------------------------- persistence

  LocalCodec? get _codec {
    final store = _store;
    if (store == null) return null;
    return LocalCodec(savePhoto: store.savePhoto, loadPhoto: store.loadPhoto);
  }

  void _save() {
    final codec = _codec;
    if (codec == null) return;
    _store!.write({
      'version': _schemaVersion,
      'sequence': _sequence,
      'session': _sessionUserId,
      'idempotency': _idempotency,
      'blacklist': {for (final b in _blacklist.entries) b.key: codec.blacklist(b.value)},
      'violationBaseline': _violationBaseline,
      // Ulasan bawaan demo dibuat ulang dari seed; yang disimpan hanya ulasan penyewa.
      'reviews': [
        for (final r in _reviews)
          if (r.rentalId != null) codec.review(r),
      ],
      // Balasan disimpan terpisah, karena ulasan bawaan demo juga bisa dibalas.
      'reviewReplies': {
        for (final r in _reviews)
          if (r.reply != null) r.id: {'reply': r.reply, 'at': r.repliedAt!.toIso8601String()},
      },
      'follows': {for (final f in _follows.entries) f.key: f.value.toList()},
      'providers': {
        for (final p in _providers)
          p.id: {
            'status': p.status.name,
            'policy': codec.policy(p.policy),
            'latitude': p.latitude,
            'longitude': p.longitude,
          },
      },
      'equipment': [for (final e in _equipment) codec.equipment(e)],
      'rentals': [for (final r in _rentals) codec.rental(r)],
    });
  }

  void _restore(Map<String, dynamic> data) {
    if (!_readableVersions.contains(data['version'])) return; // format lama: pakai seed
    final codec = _codec!;
    _sequence = data['sequence'] as int;
    _sessionUserId = data['session'] as String?;
    _idempotency.addAll((data['idempotency'] as Map).cast<String, String>());
    final blacklist = (data['blacklist'] as Map?)?.cast<String, dynamic>() ?? const {};
    _blacklist.addAll({
      for (final b in blacklist.entries)
        b.key: codec.blacklistFrom(b.value as Map<String, dynamic>),
    });
    _violationBaseline.addAll((data['violationBaseline'] as Map?)?.cast<String, int>() ?? const {});
    final providers = data['providers'] as Map<String, dynamic>;
    for (final p in _providers) {
      final saved = providers[p.id] as Map<String, dynamic>?;
      if (saved == null) continue;
      p
        ..status = ProviderStatus.values.byName(saved['status'] as String)
        ..policy = codec.policyFrom(saved['policy'] as Map<String, dynamic>)
        // Data lama belum menyimpan lokasi; pakai titik bawaan toko.
        ..latitude = (saved['latitude'] as num?)?.toDouble() ?? p.latitude
        ..longitude = (saved['longitude'] as num?)?.toDouble() ?? p.longitude;
    }
    _equipment = [
      for (final e in data['equipment'] as List) codec.equipmentFrom(e as Map<String, dynamic>),
    ];
    _rentals = [
      for (final r in data['rentals'] as List) codec.rentalFrom(r as Map<String, dynamic>),
    ];
    for (final saved in (data['reviews'] as List?) ?? const []) {
      final review = codec.reviewFrom(saved as Map<String, dynamic>);
      _reviews.add(review);
      _rentals.where((r) => r.id == review.rentalId).firstOrNull?.review = review;
    }
    final replies = (data['reviewReplies'] as Map<String, dynamic>?) ?? const {};
    for (final r in _reviews) {
      final saved = replies[r.id] as Map<String, dynamic>?;
      if (saved == null) continue;
      r
        ..reply = saved['reply'] as String
        ..repliedAt = DateTime.parse(saved['at'] as String);
    }
    final follows = data['follows'] as Map<String, dynamic>?;
    if (follows != null) {
      _follows = {for (final f in follows.entries) f.key: {...(f.value as List).cast<String>()}};
    }
  }

  /// Hitung ulang rating, jumlah ulasan, dan jumlah pengikut tiap toko.
  void _refreshStoreStats() {
    for (final p in _providers) {
      final reviews = _reviews.where((r) => r.providerId == p.id);
      p
        ..reviewCount = reviews.length
        ..rating = reviews.isEmpty
            ? 0
            : reviews.fold(0, (sum, r) => sum + r.rating) / reviews.length
        ..followerCount = _follows.values.where((ids) => ids.contains(p.id)).length;
    }
  }

  /// Menghapus semua perubahan dan kembali ke data demo awal.
  Future<void> resetDemoData() => _delay(() {
        _store?.clear();
        final fresh = SeedData(DateTime.now());
        _providers = fresh.providers();
        _equipment = List.of(fresh.equipment);
        _rentals = fresh.rentals();
        _reviews = fresh.reviews();
        _follows = fresh.follows();
        _refreshStoreStats();
        _idempotency.clear();
        _blacklist.clear();
        _violationBaseline.clear();
        _sequence = 0;
        _sessionUserId = null;
      });

  // ---------------------------------------------------------------- lookups

  Equipment _equipmentById(String id) => _equipment.firstWhere(
        (e) => e.id == id,
        orElse: () => throw const AppException('NOT_FOUND', 'Alat tidak ditemukan.'),
      );

  ProviderProfile _providerById(String id) => _providers.firstWhere(
        (p) => p.id == id,
        orElse: () => throw const AppException('NOT_FOUND', 'Penyedia tidak ditemukan.'),
      );

  Rental _rentalById(String id) => _rentals.firstWhere(
        (r) => r.id == id,
        orElse: () => throw const AppException('NOT_FOUND', 'Transaksi tidak ditemukan.'),
      );

  bool _isVisible(Equipment e) =>
      e.isActive && _providerById(e.providerId).status == ProviderStatus.verified;

  /// ALG-2 per ukuran. [size] `null` untuk alat tanpa ukuran; untuk alat
  /// berukuran, `null` berarti jumlah ketersediaan semua ukuran.
  int _available(Equipment e, DateTime start, DateTime end, [String? size]) {
    if (e.hasSizes && size == null) {
      return e.sizes.fold(0, (sum, s) => sum + _available(e, start, end, s.label));
    }
    return sweepAvailableQty(
        stockTotal: e.stockFor(size),
        start: start,
        end: end,
        ranges: [
          for (final r in _rentals)
            if (r.equipmentId == e.id &&
                r.size == size &&
                RentalStateMachine.lockingStatuses.contains(r.status))
              OccupancyRange(r.startDate, r.endDate, r.qty),
        ],
      );
  }

  // ---------------------------------------------------------------- access

  void _requireOwner(Rental r, AppUser actor) {
    if (actor.role != UserRole.provider || actor.providerId != r.providerId) {
      throw const AppException('FORBIDDEN', 'Transaksi ini bukan milik toko Anda.');
    }
  }

  void _requireRenter(Rental r, AppUser actor) {
    if (actor.role != UserRole.customer || actor.id != r.customerId) {
      throw const AppException('FORBIDDEN', 'Transaksi ini bukan milik Anda.');
    }
  }

  void _requireAdmin(AppUser actor) {
    if (actor.role != UserRole.admin) {
      throw const AppException('FORBIDDEN', 'Hanya admin yang boleh melakukan aksi ini.');
    }
  }

  // ---------------------------------------------------------------- pelanggaran

  CustomerRecord _recordOf(AppUser customer) {
    final rentals = _rentals.where((r) => r.customerId == customer.id).toList();
    return CustomerRecord(
      user: customer,
      rentalCount: rentals.length,
      lateCount: rentals.where((r) => r.lateFee > 0).length,
      noShowCount: rentals.where((r) => r.status == RentalStatus.noShow).length,
      // Denda yang masih ditinjau admin belum dihitung sebagai pelanggaran.
      damageCount: rentals
          .where((r) => r.damageFee > 0 && r.damageReview != DamageReview.pending)
          .length,
      fineTotal: rentals.fold(0, (sum, r) => sum + r.fineTotal),
      blacklist: _blacklist[customer.id],
    );
  }

  /// Dipanggil setiap kali pelanggaran penyewa bisa bertambah.
  void _autoBlacklist(String customerId) {
    if (_blacklist.containsKey(customerId)) return;
    final record = _recordOf(_users.firstWhere((u) => u.id == customerId));
    final baseline = _violationBaseline[customerId] ?? 0;
    if (!shouldAutoBlacklist(violations: record.violations, baseline: baseline)) return;
    _blacklist[customerId] = BlacklistEntry(
      reason: 'Otomatis: ${record.violations - baseline} pelanggaran '
          '(terlambat ${record.lateCount}, tidak diambil ${record.noShowCount}, '
          'merusak alat ${record.damageCount}).',
      by: 'Sistem',
      at: DateTime.now(),
    );
  }

  /// [actor] `null` = job sistem.
  void _transition(Rental r, RentalStatus to, AppUser? actor, {String? note}) {
    final error = RentalStateMachine.guardError(r, to, actor?.role);
    if (error != null) throw AppException('INVALID_TRANSITION', error);
    r.logs.add(StatusLog(
      from: r.status,
      to: to,
      actorName: switch (actor?.role) {
        null => 'Sistem',
        UserRole.provider => r.providerName,
        _ => actor!.name,
      },
      at: DateTime.now(),
      note: note,
    ));
    r.status = to;
  }

  // ---------------------------------------------------------------- auth

  @override
  Future<AppUser> login(String email, String password) => _mutate(() {
        final user = _users.where((u) => u.email == email.trim().toLowerCase());
        if (user.isEmpty || password != demoPassword) {
          throw const AppException('AUTH_FAILED', 'Email atau password salah.');
        }
        _sessionUserId = user.first.id;
        return user.first;
      });

  @override
  Future<AppUser?> restoreSession() => _delay(() {
        final id = _sessionUserId;
        return id == null ? null : _users.where((u) => u.id == id).firstOrNull;
      });

  @override
  Future<void> logout() => _mutate(() => _sessionUserId = null);

  // ---------------------------------------------------------------- jobs

  /// Pengganti Laravel Scheduler selama belum ada server: dijalankan saat
  /// aplikasi dibuka dan saat login.
  @override
  Future<int> runScheduledJobs() => _mutate(() {
        final now = DateTime.now();
        final today = dateOnly(now);
        var changed = 0;
        void apply(Rental r, RentalStatus to, String note) {
          _transition(r, to, null, note: note);
          if (to == RentalStatus.expired || to == RentalStatus.cancelled) {
            r.cancelReason = note;
          }
          changed++;
        }

        for (final r in _rentals) {
          final since = now.difference(r.logs.last.at);
          switch (r.status) {
            case RentalStatus.pendingConfirmation when since > const Duration(hours: 12):
              apply(r, RentalStatus.expired, 'Penyedia tidak merespons dalam 12 jam');
            case RentalStatus.awaitingPayment when since > const Duration(hours: 24):
              apply(r, RentalStatus.cancelled, 'Tidak dibayar dalam 24 jam');
            case RentalStatus.paid when today.isAfter(r.startDate):
              apply(r, RentalStatus.noShow, 'Alat tidak diambil sampai tanggal mulai lewat');
              _autoBlacklist(r.customerId);
            case RentalStatus.pickedUp when today.isAfter(r.endDate):
              apply(r, RentalStatus.overdue, 'Melewati tanggal selesai');
            default:
              break;
          }
        }
        return changed;
      });

  // ---------------------------------------------------------------- catalog

  @override
  Future<List<Category>> categories() => _delay(() => List.of(_categories));

  @override
  Future<List<Equipment>> searchEquipment({String query = '', String? categoryId}) =>
      _delay(() {
        final q = query.trim().toLowerCase();
        return _equipment
            .where(_isVisible)
            .where((e) => categoryId == null || e.categoryId == categoryId)
            .where((e) =>
                q.isEmpty ||
                e.name.toLowerCase().contains(q) ||
                e.brand.toLowerCase().contains(q))
            .toList();
      });

  @override
  Future<List<Equipment>> providerEquipment(String providerId) =>
      _delay(() => _equipment.where((e) => e.providerId == providerId).toList());

  @override
  Future<Equipment> equipment(String id) => _delay(() => _equipmentById(id));

  @override
  Future<ProviderProfile> provider(String id) => _delay(() => _providerById(id));

  @override
  Future<List<ProviderProfile>> providers() => _delay(() => List.of(_providers));

  @override
  Future<int> availableQty(String equipmentId, DateTime start, DateTime end, {String? size}) =>
      _delay(() => _available(_equipmentById(equipmentId), start, end, size));

  @override
  Future<Map<String, int>> sizeAvailability(String equipmentId, DateTime start, DateTime end) =>
      _delay(() {
        final e = _equipmentById(equipmentId);
        return {for (final s in e.sizes) s.label: _available(e, start, end, s.label)};
      });

  // ---------------------------------------------------------------- booking

  @override
  Future<Rental> createBooking(BookingRequest req) => _mutate(() {
        // Kirim ulang dengan key yang sama tidak membuat booking ganda.
        final existing = _idempotency[req.idempotencyKey];
        if (existing != null) return _rentalById(existing);

        final customer = _users.firstWhere((u) => u.id == req.customerId);
        if (customer.role != UserRole.customer) {
          throw const AppException('FORBIDDEN', 'Hanya penyewa yang bisa membuat booking.');
        }
        final blocked = _blacklist[customer.id];
        if (blocked != null) {
          throw AppException('BLACKLISTED',
              'Akun Anda masuk blacklist dan tidak bisa membuat booking. Alasan: ${blocked.reason}');
        }
        final e = _equipmentById(req.equipmentId);
        final p = _providerById(e.providerId);
        if (p.status != ProviderStatus.verified) {
          throw const AppException('PROVIDER_INACTIVE', 'Penyedia belum terverifikasi.');
        }

        final start = dateOnly(req.startDate);
        final end = dateOnly(req.endDate);
        if (start.isBefore(dateOnly(DateTime.now()))) {
          throw const AppException('INVALID_DATE', 'Tanggal mulai sudah lewat.');
        }
        if (end.isBefore(start)) {
          throw const AppException('INVALID_DATE', 'Tanggal selesai sebelum tanggal mulai.');
        }
        if (req.qty < 1) {
          throw const AppException('INVALID_QTY', 'Jumlah minimal 1.');
        }
        if (e.hasSizes && !e.sizes.any((s) => s.label == req.size)) {
          throw const AppException('SIZE_REQUIRED', 'Pilih ukuran terlebih dahulu.');
        }
        if (!e.hasSizes && req.size != null) {
          throw const AppException('VALIDATION', 'Alat ini tidak memiliki pilihan ukuran.');
        }
        if (!e.isActive) {
          throw const AppException('NOT_FOUND', 'Alat sedang tidak disewakan.');
        }

        // Cek ulang ketersediaan tepat sebelum menulis (di server: di dalam
        // transaksi DB + lockForUpdate). Dart berjalan satu thread, jadi blok
        // sinkron ini sudah atomik.
        if (_available(e, start, end, req.size) < req.qty) {
          throw const AppException('SLOT_UNAVAILABLE', 'Stok tidak cukup pada tanggal tersebut.');
        }

        final days = inclusiveDays(start, end);
        final total = e.pricePerDay * req.qty * days + e.depositAmount * req.qty;
        final errors = p.policy.validate(req.guarantees,
            rentalValue: total, renterName: customer.name);
        if (errors.isNotEmpty) {
          throw AppException('GUARANTEE_INVALID', errors.join('\n'));
        }

        _sequence++;
        final now = DateTime.now();
        final id = 'r-${now.microsecondsSinceEpoch}';
        final rental = Rental(
          id: id,
          invoiceCode:
              'INV-${now.year}${_two(now.month)}${_two(now.day)}-${_sequence.toString().padLeft(4, '0')}',
          customerId: customer.id,
          customerName: customer.name,
          providerId: p.id,
          providerName: p.businessName,
          equipmentId: e.id,
          equipmentName: e.name,
          categoryId: e.categoryId,
          qty: req.qty,
          size: req.size,
          photo: e.photos.firstOrNull,
          startDate: start,
          endDate: end,
          pricePerDaySnapshot: e.pricePerDay,
          depositSnapshot: e.depositAmount,
          status: RentalStatus.pendingConfirmation,
          createdAt: now,
          guarantees: [
            for (final (i, d) in req.guarantees.indexed)
              Guarantee(
                id: '$id-g$i',
                type: d.type!,
                holderName: d.holderName.trim(),
                documentNumber: d.documentNumber.replaceAll(RegExp(r'\s'), ''),
                photo: d.photo,
              ),
          ],
          logs: [
            StatusLog(from: null, to: RentalStatus.pendingConfirmation, actorName: customer.name, at: now),
          ],
        );
        _rentals.add(rental);
        _idempotency[req.idempotencyKey] = id;
        return rental;
      });

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Future<Rental> rental(String id) => _delay(() => _rentalById(id));

  List<Rental> _sorted(Iterable<Rental> list) =>
      list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Rental>> customerRentals(String customerId) =>
      _delay(() => _sorted(_rentals.where((r) => r.customerId == customerId)));

  @override
  Future<List<Rental>> providerRentals(String providerId) =>
      _delay(() => _sorted(_rentals.where((r) => r.providerId == providerId)));

  @override
  Future<List<Rental>> allRentals() => _delay(() => _sorted(_rentals));

  // ---------------------------------------------------------------- guarantee flow

  @override
  Future<Rental> reviewGuarantee(
    String rentalId,
    String guaranteeId,
    AppUser actor, {
    required bool accept,
    String? note,
  }) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        if (r.status != RentalStatus.pendingConfirmation) {
          throw const AppException('INVALID_STATE', 'Jaminan hanya bisa diperiksa sebelum konfirmasi.');
        }
        final g = r.guarantees.firstWhere((x) => x.id == guaranteeId);
        g
          ..status = accept ? GuaranteeStatus.verified : GuaranteeStatus.rejected
          ..note = note;
        return r;
      });

  @override
  Future<Rental> confirmBooking(String rentalId, AppUser actor) => _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        _transition(r, RentalStatus.awaitingPayment, actor);
        return r;
      });

  @override
  Future<Rental> rejectBooking(String rentalId, AppUser actor, String reason) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        _transition(r, RentalStatus.rejected, actor, note: reason);
        r.cancelReason = reason;
        return r;
      });

  @override
  Future<Rental> cancelBooking(String rentalId, AppUser actor, String reason) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireRenter(r, actor);
        _transition(r, RentalStatus.cancelled, actor, note: reason);
        r.cancelReason = reason;
        return r;
      });

  @override
  Future<Rental> submitPayment(String rentalId, AppUser actor, Uint8List proof) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireRenter(r, actor);
        // Versi mock: bukti langsung dianggap sah. Di server, bukti masuk
        // tabel payments berstatus pending dan diverifikasi dulu.
        _transition(r, RentalStatus.paid, actor, note: 'Bukti transfer diunggah');
        r.paymentProof = proof;
        return r;
      });

  @override
  Future<Rental> handover(String rentalId, AppUser actor) => _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        if (r.status != RentalStatus.paid) {
          throw const AppException('INVALID_STATE', 'Alat hanya bisa diserahkan setelah pembayaran.');
        }
        final now = DateTime.now();
        for (final g in r.guarantees) {
          g
            ..status = GuaranteeStatus.held
            ..heldAt = now;
        }
        _transition(r, RentalStatus.pickedUp, actor,
            note: 'Dokumen asli jaminan diterima provider');
        return r;
      });

  @override
  Future<Rental> receiveReturn(
    String rentalId,
    AppUser actor, {
    ReturnCondition condition = ReturnCondition.good,
    double damageFee = 0,
    String? damageNote,
  }) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        final error = damageFeeError(condition, damageFee, r.depositTotal);
        if (error != null) throw AppException('VALIDATION', error);

        final now = DateTime.now();
        final days = lateDays(r.endDate, now);
        final lateFee = lateFeeFor(pricePerDay: r.pricePerDaySnapshot, qty: r.qty, days: days);
        final needsReview = needsAdminReview(damageFee, r.depositTotal);
        _transition(r, RentalStatus.returned, actor,
            note: [
              'Kondisi alat: ${condition.label}',
              if (days > 0) 'Terlambat $days hari',
            ].join('. '));
        r
          ..returnedAt = now
          ..returnCondition = condition
          ..lateFee = lateFee
          ..damageFee = damageFee
          ..damageNote = damageNote?.trim()
          ..damageReview = needsReview ? DamageReview.pending : DamageReview.none
          ..reviewReason = needsReview ?'Denda kerusakan lebih dari separuh deposit.' : null;
        _autoBlacklist(r.customerId);
        return r;
      });

  @override
  Future<Rental> objectToDamageFee(String rentalId, AppUser actor, String reason) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireRenter(r, actor);
        if (!r.canObjectToDamageFee) {
          throw const AppException('INVALID_STATE', 'Denda ini tidak bisa diajukan keberatan.');
        }
        r
          ..damageReview = DamageReview.pending
          ..reviewReason = 'Keberatan penyewa: ${reason.trim()}';
        return r;
      });

  @override
  Future<Rental> decideDamageFee(String rentalId, AppUser actor,
          {required double amount, String? note}) =>
      _mutate(() {
        _requireAdmin(actor);
        final r = _rentalById(rentalId);
        if (r.damageReview != DamageReview.pending) {
          throw const AppException('INVALID_STATE', 'Tidak ada denda yang menunggu tinjauan.');
        }
        if (amount < 0 || amount > r.depositTotal) {
          throw const AppException('VALIDATION', 'Nominal harus antara 0 dan jumlah deposit.');
        }
        r
          ..damageFee = amount
          ..damageReview = DamageReview.decided
          ..reviewNote = note?.trim();
        _autoBlacklist(r.customerId);
        return r;
      });

  @override
  Future<Rental> returnGuaranteesAndComplete(String rentalId, AppUser actor) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireOwner(r, actor);
        if (r.status != RentalStatus.returned) {
          throw const AppException('INVALID_STATE', 'Alat belum dikembalikan.');
        }
        if (r.damageReview == DamageReview.pending) {
          throw const AppException(
              'DAMAGE_REVIEW_PENDING', 'Denda kerusakan masih ditinjau admin.');
        }
        final now = DateTime.now();
        for (final g in r.guarantees) {
          g
            ..status = GuaranteeStatus.returned
            ..returnedAt = now;
        }
        _transition(r, RentalStatus.completed, actor,
            note: 'Dokumen asli jaminan dikembalikan ke penyewa');
        return r;
      });

  // ---------------------------------------------------------------- provider & admin

  @override
  Future<Equipment> saveEquipment(Equipment draft, AppUser actor) => _mutate(() {
        final providerId = actor.providerId;
        if (actor.role != UserRole.provider || providerId == null) {
          throw const AppException('FORBIDDEN', 'Hanya penyedia yang bisa mengelola alat.');
        }
        final isNew = draft.id.isEmpty;
        if (!isNew && _equipmentById(draft.id).providerId != providerId) {
          throw const AppException('FORBIDDEN', 'Alat ini bukan milik toko Anda.');
        }
        final errors = validateEquipment(draft);
        if (errors.isNotEmpty) throw AppException('VALIDATION', errors.join('\n'));

        final saved = Equipment(
          id: isNew ? 'e-${DateTime.now().microsecondsSinceEpoch}' : draft.id,
          providerId: providerId,
          categoryId: draft.categoryId,
          name: draft.name.trim(),
          brand: draft.brand.trim(),
          description: draft.description.trim(),
          pricePerDay: draft.pricePerDay,
          depositAmount: draft.depositAmount,
          weightGram: draft.weightGram,
          stock: draft.hasSizes ? 0 : draft.stock,
          sizes: draft.sizes,
          photos: draft.photos,
          rating: isNew ? 0 : _equipmentById(draft.id).rating,
          conditionScore: isNew ? 100 : _equipmentById(draft.id).conditionScore,
          capacityPerson: draft.capacityPerson,
          isActive: draft.isActive,
        );
        if (isNew) {
          _equipment.add(saved);
        } else {
          _equipment[_equipment.indexWhere((e) => e.id == saved.id)] = saved;
        }
        return saved;
      });

  @override
  Future<ProviderProfile> updateGuaranteePolicy(
          String providerId, GuaranteePolicy policy, AppUser actor) =>
      _mutate(() {
        final p = _providerById(providerId);
        if (actor.providerId != p.id) {
          throw const AppException('FORBIDDEN', 'Bukan toko Anda.');
        }
        if (policy.acceptedTypes.isEmpty) {
          throw const AppException('VALIDATION', 'Pilih minimal satu jenis jaminan.');
        }
        if (policy.acceptedTypes.length < policy.requiredCount(double.infinity)) {
          throw const AppException('VALIDATION',
              'Jenis jaminan yang diterima lebih sedikit dari jumlah jaminan yang diminta.');
        }
        p.policy = policy;
        return p;
      });

  @override
  Future<ProviderProfile> updateProviderLocation(String providerId, AppUser actor,
          {required double latitude, required double longitude}) =>
      _mutate(() {
        final p = _providerById(providerId);
        if (actor.providerId != p.id) {
          throw const AppException('FORBIDDEN', 'Bukan toko Anda.');
        }
        if (latitude.abs() > 90 || longitude.abs() > 180) {
          throw const AppException('VALIDATION', 'Titik lokasi tidak valid.');
        }
        p
          ..latitude = latitude
          ..longitude = longitude;
        return p;
      });

  @override
  Future<ProviderProfile> setProviderStatus(
          String providerId, ProviderStatus status, AppUser actor) =>
      _mutate(() {
        _requireAdmin(actor);
        final p = _providerById(providerId);
        p.status = status;
        return p;
      });

  // ---------------------------------------------------------------- toko

  @override
  Future<List<Review>> providerReviews(String providerId) => _delay(() =>
      _reviews.where((r) => r.providerId == providerId).toList()
        ..sort((a, b) => b.at.compareTo(a.at)));

  @override
  Future<Review> replyToReview(String reviewId, AppUser actor, String reply) => _mutate(() {
        final review = _reviews.firstWhere(
          (r) => r.id == reviewId,
          orElse: () => throw const AppException('NOT_FOUND', 'Ulasan tidak ditemukan.'),
        );
        if (actor.role != UserRole.provider || actor.providerId != review.providerId) {
          throw const AppException('FORBIDDEN', 'Hanya pemilik toko yang bisa membalas ulasan.');
        }
        final text = reply.trim();
        if (text.isEmpty || text.length > 500) {
          throw const AppException('VALIDATION', 'Balasan harus diisi, paling banyak 500 huruf.');
        }
        review
          ..reply = text
          ..repliedAt = DateTime.now();
        return review;
      });

  @override
  Future<Rental> submitReview(String rentalId, AppUser actor,
          {required int rating, String comment = ''}) =>
      _mutate(() {
        final r = _rentalById(rentalId);
        _requireRenter(r, actor);
        if (r.status != RentalStatus.completed) {
          throw const AppException('INVALID_STATE', 'Ulasan hanya untuk transaksi yang sudah selesai.');
        }
        if (r.review != null) {
          throw const AppException('ALREADY_REVIEWED', 'Transaksi ini sudah Anda ulas.');
        }
        if (rating < 1 || rating > 5) {
          throw const AppException('VALIDATION', 'Pilih 1 sampai 5 bintang.');
        }
        final review = Review(
          id: 'rv-${r.id}',
          providerId: r.providerId,
          customerName: actor.name,
          rating: rating,
          comment: comment.trim(),
          at: DateTime.now(),
          rentalId: r.id,
          equipmentName: r.equipmentName,
        );
        r.review = review;
        _reviews.add(review);
        _refreshStoreStats();
        return r;
      });

  @override
  Future<Set<String>> followedProviders(String customerId) =>
      _delay(() => {...?_follows[customerId]});

  @override
  Future<ProviderProfile> setFollow(String providerId, AppUser actor, {required bool follow}) =>
      _mutate(() {
        if (actor.role != UserRole.customer) {
          throw const AppException('FORBIDDEN', 'Hanya penyewa yang bisa mengikuti toko.');
        }
        final p = _providerById(providerId);
        final followed = _follows.putIfAbsent(actor.id, () => {});
        if (follow) {
          followed.add(p.id);
        } else {
          followed.remove(p.id);
        }
        _refreshStoreStats();
        return p;
      });

  // ---------------------------------------------------------------- blacklist

  @override
  Future<List<CustomerRecord>> customers(AppUser actor) => _delay(() {
        _requireAdmin(actor);
        return [
          for (final u in _users)
            if (u.role == UserRole.customer) _recordOf(u),
        ];
      });

  @override
  Future<BlacklistEntry?> blacklistOf(String userId) => _delay(() => _blacklist[userId]);

  @override
  Future<void> setBlacklist(String customerId, AppUser actor,
          {required bool blocked, String? reason}) =>
      _mutate(() {
        _requireAdmin(actor);
        final customer = _users.firstWhere(
          (u) => u.id == customerId && u.role == UserRole.customer,
          orElse: () => throw const AppException('NOT_FOUND', 'Penyewa tidak ditemukan.'),
        );
        if (!blocked) {
          _blacklist.remove(customer.id);
          _violationBaseline[customer.id] = _recordOf(customer).violations;
          return;
        }
        final text = reason?.trim() ?? '';
        if (text.isEmpty) {
          throw const AppException('VALIDATION', 'Alasan blacklist wajib diisi.');
        }
        _blacklist[customer.id] = BlacklistEntry(reason: text, by: actor.name, at: DateTime.now());
      });
}
