import 'dart:typed_data';

import '../domain/guarantee.dart';
import '../domain/models.dart';

/// Konversi objek domain <-> JSON untuk penyimpanan lokal.
/// Foto tidak masuk JSON; [savePhoto]/[loadPhoto] menyimpannya sebagai file.
class LocalCodec {
  LocalCodec({required this.savePhoto, required this.loadPhoto});

  final String Function(String name, Uint8List bytes) savePhoto;
  final Uint8List? Function(String? fileName) loadPhoto;

  static String? _date(DateTime? d) => d?.toIso8601String();
  static DateTime? _parse(Object? s) => s == null ? null : DateTime.parse(s as String);

  Map<String, dynamic> policy(GuaranteePolicy p) => {
        'acceptedTypes': [for (final t in p.acceptedTypes) t.name],
        'baseRequired': p.baseRequired,
        'highValueThreshold': p.highValueThreshold,
        'highValueRequired': p.highValueRequired,
      };

  GuaranteePolicy policyFrom(Map<String, dynamic> j) => GuaranteePolicy(
        acceptedTypes: {
          for (final n in j['acceptedTypes'] as List) GuaranteeType.values.byName(n as String),
        },
        baseRequired: j['baseRequired'] as int,
        highValueThreshold: (j['highValueThreshold'] as num).toDouble(),
        highValueRequired: j['highValueRequired'] as int,
      );

  Map<String, dynamic> photo(ItemPhoto p) => switch (p) {
        AssetPhoto(:final path) => {'asset': path},
        MemoryPhoto(:final id, :final bytes) => {'id': id, 'file': savePhoto(id, bytes)},
      };

  ItemPhoto? photoFrom(Map<String, dynamic> j) {
    final asset = j['asset'] as String?;
    if (asset != null) return AssetPhoto(asset);
    final bytes = loadPhoto(j['file'] as String?);
    return bytes == null ? null : MemoryPhoto(j['id'] as String, bytes);
  }

  Map<String, dynamic> equipment(Equipment e) => {
        'id': e.id,
        'providerId': e.providerId,
        'categoryId': e.categoryId,
        'name': e.name,
        'brand': e.brand,
        'description': e.description,
        'pricePerDay': e.pricePerDay,
        'depositAmount': e.depositAmount,
        'weightGram': e.weightGram,
        'stock': e.stock,
        'sizes': [for (final s in e.sizes) {'label': s.label, 'stock': s.stock}],
        'photos': [for (final p in e.photos) photo(p)],
        'rating': e.rating,
        'conditionScore': e.conditionScore,
        'capacityPerson': e.capacityPerson,
        'isActive': e.isActive,
      };

  Equipment equipmentFrom(Map<String, dynamic> j) => Equipment(
        id: j['id'] as String,
        providerId: j['providerId'] as String,
        categoryId: j['categoryId'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String,
        description: j['description'] as String,
        pricePerDay: (j['pricePerDay'] as num).toDouble(),
        depositAmount: (j['depositAmount'] as num).toDouble(),
        weightGram: j['weightGram'] as int,
        stock: j['stock'] as int,
        sizes: [
          for (final s in (j['sizes'] as List).cast<Map<String, dynamic>>())
            SizeStock(s['label'] as String, s['stock'] as int),
        ],
        photos: [
          for (final p in (j['photos'] as List).cast<Map<String, dynamic>>()) ?photoFrom(p),
        ],
        rating: (j['rating'] as num).toDouble(),
        conditionScore: j['conditionScore'] as int,
        capacityPerson: j['capacityPerson'] as int?,
        isActive: j['isActive'] as bool,
      );

  Map<String, dynamic> guarantee(Guarantee g) => {
        'id': g.id,
        'type': g.type.name,
        'holderName': g.holderName,
        'documentNumber': g.documentNumber,
        'photo': g.photo == null ? null : savePhoto(g.id, g.photo!),
        'status': g.status.name,
        'note': g.note,
        'heldAt': _date(g.heldAt),
        'returnedAt': _date(g.returnedAt),
      };

  Guarantee guaranteeFrom(Map<String, dynamic> j) => Guarantee(
        id: j['id'] as String,
        type: GuaranteeType.values.byName(j['type'] as String),
        holderName: j['holderName'] as String,
        documentNumber: j['documentNumber'] as String,
        photo: loadPhoto(j['photo'] as String?),
        status: GuaranteeStatus.values.byName(j['status'] as String),
        note: j['note'] as String?,
      )
        ..heldAt = _parse(j['heldAt'])
        ..returnedAt = _parse(j['returnedAt']);

  Map<String, dynamic> rental(Rental r) => {
        'id': r.id,
        'invoiceCode': r.invoiceCode,
        'customerId': r.customerId,
        'customerName': r.customerName,
        'providerId': r.providerId,
        'providerName': r.providerName,
        'equipmentId': r.equipmentId,
        'equipmentName': r.equipmentName,
        'categoryId': r.categoryId,
        'qty': r.qty,
        'size': r.size,
        'photo': r.photo == null ? null : photo(r.photo!),
        'startDate': _date(r.startDate),
        'endDate': _date(r.endDate),
        'pricePerDaySnapshot': r.pricePerDaySnapshot,
        'depositSnapshot': r.depositSnapshot,
        'status': r.status.name,
        'createdAt': _date(r.createdAt),
        'cancelReason': r.cancelReason,
        'paymentProof': r.paymentProof == null ? null : savePhoto('${r.id}-payment', r.paymentProof!),
        'guarantees': [for (final g in r.guarantees) guarantee(g)],
        'logs': [
          for (final l in r.logs)
            {
              'from': l.from?.name,
              'to': l.to.name,
              'actorName': l.actorName,
              'at': _date(l.at),
              'note': l.note,
            },
        ],
      };

  Rental rentalFrom(Map<String, dynamic> j) => Rental(
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
        photo: j['photo'] == null ? null : photoFrom(j['photo'] as Map<String, dynamic>),
        startDate: _parse(j['startDate'])!,
        endDate: _parse(j['endDate'])!,
        pricePerDaySnapshot: (j['pricePerDaySnapshot'] as num).toDouble(),
        depositSnapshot: (j['depositSnapshot'] as num).toDouble(),
        status: RentalStatus.values.byName(j['status'] as String),
        createdAt: _parse(j['createdAt'])!,
        guarantees: [
          for (final g in j['guarantees'] as List) guaranteeFrom(g as Map<String, dynamic>),
        ],
        logs: [
          for (final l in (j['logs'] as List).cast<Map<String, dynamic>>())
            StatusLog(
              from: l['from'] == null ? null : RentalStatus.values.byName(l['from'] as String),
              to: RentalStatus.values.byName(l['to'] as String),
              actorName: l['actorName'] as String,
              at: _parse(l['at'])!,
              note: l['note'] as String?,
            ),
        ],
      )
        ..cancelReason = j['cancelReason'] as String?
        ..paymentProof = loadPhoto(j['paymentProof'] as String?);
}
