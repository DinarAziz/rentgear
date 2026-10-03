import '../domain/fines.dart';
import '../domain/guarantee.dart';
import '../domain/models.dart';

/// JSON dari server Laravel -> objek domain. Nama kunci mengikuti
/// `Present` di `rentgear_api/app/Http/Presenters/Present.php`.
abstract final class ApiCodec {
  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  /// Tanggal sewa dikirim sebagai tanggal kalender ("2026-10-03"), tanpa jam.
  static DateTime _date(Object? value) {
    final parts = (value as String).split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

  static T? _byName<T extends Enum>(List<T> values, Object? name) =>
      name == null ? null : values.byName(name as String);

  static List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List).cast<Map<String, dynamic>>();

  static AppUser user(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        role: UserRole.values.byName(j['role'] as String),
        city: j['city'] as String,
        providerId: j['providerId'] as String?,
      );

  static AiRecommendation aiRecommendation(Map<String, dynamic> j) => AiRecommendation(
        summary: j['summary'] as String,
        items: [
          for (final i in (j['items'] as List).cast<Map<String, dynamic>>())
            AiPick(
              equipmentId: i['equipmentId'] as String,
              name: i['name'] as String,
              providerName: i['providerName'] as String,
              city: i['city'] as String,
              qty: i['qty'] as int,
              reason: i['reason'] as String,
              rentCost: _double(i['rentCost']),
              deposit: _double(i['deposit']),
            ),
        ],
        tips: (j['tips'] as List).cast<String>(),
        days: j['days'] as int,
        people: j['people'] as int,
        rentTotal: _double(j['rentTotal']),
        depositTotal: _double(j['depositTotal']),
      );

  static AiFineOpinion aiFineOpinion(Map<String, dynamic> j) => AiFineOpinion(
        verdict: j['verdict'] as String,
        suggestedFee: _double(j['suggestedFee']),
        explanation: j['explanation'] as String,
        proposedFee: _double(j['proposedFee']),
        photoFinding: (j['photoFinding'] as String?) ?? '',
        photosBefore: (j['photosBefore'] as int?) ?? 0,
        photosAfter: (j['photosAfter'] as int?) ?? 0,
      );

  static AiRisk aiRisk(Map<String, dynamic> j) => AiRisk(
        level: j['level'] as String,
        summary: j['summary'] as String,
        factors: (j['factors'] as List).cast<String>(),
      );

  static AuditEntry audit(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] as String,
        at: _time(j['at'])!,
        actorName: j['actorName'] as String,
        actorRole: j['actorRole'] as String,
        action: j['action'] as String,
        target: j['target'] as String?,
        detail: j['detail'] as String?,
      );

  static Map<String, dynamic> policyToJson(GuaranteePolicy p) => {
        'acceptedTypes': [for (final t in p.acceptedTypes) t.name],
        'baseRequired': p.baseRequired,
        'highValueThreshold': p.highValueThreshold,
        'highValueRequired': p.highValueRequired,
      };

  static ProviderProfile provider(Map<String, dynamic> j) {
    final policy = j['policy'] as Map<String, dynamic>;
    return ProviderProfile(
      id: j['id'] as String,
      ownerId: j['ownerId'] as String,
      businessName: j['businessName'] as String,
      city: j['city'] as String,
      address: j['address'] as String,
      status: ProviderStatus.values.byName(j['status'] as String),
      latitude: _double(j['latitude']),
      longitude: _double(j['longitude']),
      bankAccount: j['bankAccount'] as String?,
      policy: GuaranteePolicy(
        acceptedTypes: {
          for (final t in policy['acceptedTypes'] as List) GuaranteeType.values.byName(t as String),
        },
        baseRequired: policy['baseRequired'] as int,
        highValueThreshold: _double(policy['highValueThreshold']),
        highValueRequired: policy['highValueRequired'] as int,
      ),
    )
      ..rating = _double(j['rating'])
      ..reviewCount = j['reviewCount'] as int
      ..followerCount = j['followerCount'] as int;
  }

  static Equipment equipment(Map<String, dynamic> j) => Equipment(
        id: j['id'] as String,
        providerId: j['providerId'] as String,
        categoryId: j['categoryId'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String,
        description: j['description'] as String,
        pricePerDay: _double(j['pricePerDay']),
        depositAmount: _double(j['depositAmount']),
        weightGram: j['weightGram'] as int,
        stock: j['stock'] as int,
        sizes: [
          for (final s in _maps(j['sizes']))
            SizeStock(s['label'] as String, s['stock'] as int),
        ],
        photos: [
          for (final p in _maps(j['photos']))
            NetworkPhoto(p['id'] as String, p['url'] as String),
        ],
        rating: _double(j['rating']),
        conditionScore: j['conditionScore'] as int,
        capacityPerson: j['capacityPerson'] as int?,
        isActive: j['isActive'] as bool,
      );

  static Review review(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        providerId: j['providerId'] as String,
        customerName: j['customerName'] as String,
        rating: j['rating'] as int,
        comment: j['comment'] as String,
        at: _time(j['at'])!,
        rentalId: j['rentalId'] as String?,
        equipmentName: j['equipmentName'] as String?,
        reply: j['reply'] as String?,
        repliedAt: _time(j['repliedAt']),
      );

  /// Server hanya mengirim nomor dokumen yang sudah disamarkan.
  static Guarantee guarantee(Map<String, dynamic> j) => Guarantee(
        id: j['id'] as String,
        type: GuaranteeType.values.byName(j['type'] as String),
        holderName: j['holderName'] as String,
        documentNumber: j['maskedNumber'] as String,
        status: GuaranteeStatus.values.byName(j['status'] as String),
        note: j['note'] as String?,
      )
        ..heldAt = _time(j['heldAt'])
        ..returnedAt = _time(j['returnedAt']);

  static Rental rental(Map<String, dynamic> j) {
    final photoUrl = j['photoUrl'] as String?;
    final review = j['review'] as Map<String, dynamic>?;
    return Rental(
      id: j['id'] as String,
      invoiceCode: j['invoiceCode'] as String,
      customerId: j['customerId'] as String,
      customerName: j['customerName'] as String,
      providerId: j['providerId'] as String,
      providerName: j['providerName'] as String,
      equipmentId: j['equipmentId'] as String,
      equipmentName: j['equipmentName'] as String,
      categoryId: j['categoryId'] as String,
      qty: j['qty'] as int,
      size: j['size'] as String?,
      photo: photoUrl == null ? null : NetworkPhoto('${j['id']}-photo', photoUrl),
      startDate: _date(j['startDate']),
      endDate: _date(j['endDate']),
      pricePerDaySnapshot: _double(j['pricePerDaySnapshot']),
      depositSnapshot: _double(j['depositSnapshot']),
      status: RentalStatus.values.byName(j['status'] as String),
      createdAt: _time(j['createdAt'])!,
      guarantees: [
        for (final g in _maps(j['guarantees'])) guarantee(g),
      ],
      logs: [
        for (final l in _maps(j['logs']))
          StatusLog(
            from: _byName(RentalStatus.values, l['from']),
            to: RentalStatus.values.byName(l['to'] as String),
            actorName: l['actorName'] as String,
            at: _time(l['at'])!,
            note: l['note'] as String?,
          ),
      ],
    )
      ..cancelReason = j['cancelReason'] as String?
      ..returnedAt = _time(j['returnedAt'])
      ..returnCondition = _byName(ReturnCondition.values, j['returnCondition'])
      ..lateFee = _double(j['lateFee'])
      ..damageFee = _double(j['damageFee'])
      ..damageNote = j['damageNote'] as String?
      ..damageReview = _byName(DamageReview.values, j['damageReview']) ?? DamageReview.none
      ..reviewReason = j['reviewReason'] as String?
      ..reviewNote = j['reviewNote'] as String?
      ..review = review == null ? null : ApiCodec.review(review);
  }

  static BlacklistEntry? blacklist(Map<String, dynamic>? j) => j == null
      ? null
      : BlacklistEntry(reason: j['reason'] as String, by: j['by'] as String, at: _time(j['at'])!);

  static CustomerRecord customerRecord(Map<String, dynamic> j) => CustomerRecord(
        user: user(j['user'] as Map<String, dynamic>),
        rentalCount: j['rentalCount'] as int,
        lateCount: j['lateCount'] as int,
        noShowCount: j['noShowCount'] as int,
        damageCount: j['damageCount'] as int,
        fineTotal: _double(j['fineTotal']),
        blacklist: blacklist(j['blacklist'] as Map<String, dynamic>?),
      );
}
