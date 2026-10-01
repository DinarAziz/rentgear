import 'dart:math';

import '../domain/availability.dart';
import '../domain/guarantee.dart';
import '../domain/models.dart';

/// Data contoh untuk demo. Semua akun memakai password `password`.
class SeedData {
  SeedData(this.now) : today = dateOnly(now);

  final DateTime now;
  final DateTime today;

  DateTime day(int offset) => today.add(Duration(days: offset));

  final users = const [
    AppUser(id: 'u-budi', name: 'Budi Santoso', email: 'budi@rentgear.id', phone: '081234567801', role: UserRole.customer, city: 'Malang'),
    AppUser(id: 'u-rina', name: 'Rina Putri', email: 'rina@rentgear.id', phone: '081234567802', role: UserRole.customer, city: 'Surabaya'),
    AppUser(id: 'u-sari', name: 'Sari Wulandari', email: 'sari@rentgear.id', phone: '081234567803', role: UserRole.provider, city: 'Malang', providerId: 'p-arjuna'),
    AppUser(id: 'u-dewi', name: 'Dewi Lestari', email: 'dewi@rentgear.id', phone: '081234567804', role: UserRole.provider, city: 'Lumajang', providerId: 'p-semeru'),
    AppUser(id: 'u-agus', name: 'Agus Pratama', email: 'agus@rentgear.id', phone: '081234567805', role: UserRole.provider, city: 'Batu', providerId: 'p-puncak'),
    AppUser(id: 'u-admin', name: 'Admin RentGear', email: 'admin@rentgear.id', phone: '081234567800', role: UserRole.admin, city: 'Malang'),
  ];

  List<ProviderProfile> providers() => [
        ProviderProfile(
          id: 'p-arjuna',
          ownerId: 'u-sari',
          businessName: 'Arjuna Outdoor',
          city: 'Malang',
          address: 'Jl. Soekarno Hatta No. 12, Malang',
          status: ProviderStatus.verified,
          rating: 4.8,
          bankAccount: 'BCA 0231 4455 67 a.n. Arjuna Outdoor',
          policy: const GuaranteePolicy(
            acceptedTypes: {GuaranteeType.ktp, GuaranteeType.sim, GuaranteeType.ktm, GuaranteeType.kartuKeluarga},
          ),
        ),
        ProviderProfile(
          id: 'p-semeru',
          ownerId: 'u-dewi',
          businessName: 'Semeru Camp Rent',
          city: 'Lumajang',
          address: 'Jl. Raya Senduro No. 5, Lumajang',
          status: ProviderStatus.verified,
          rating: 4.9,
          bankAccount: 'BRI 0012 01 000456 30 1 a.n. Dewi Lestari',
          policy: const GuaranteePolicy(
            acceptedTypes: {GuaranteeType.ktp, GuaranteeType.ktm, GuaranteeType.ijazah, GuaranteeType.paspor},
            highValueThreshold: 750000,
          ),
        ),
        ProviderProfile(
          id: 'p-puncak',
          ownerId: 'u-agus',
          businessName: 'Puncak Outdoor',
          city: 'Batu',
          address: 'Jl. Panglima Sudirman No. 88, Batu',
          status: ProviderStatus.pending,
          rating: 0,
          policy: const GuaranteePolicy(acceptedTypes: {GuaranteeType.ktp, GuaranteeType.sim}),
        ),
      ];

  final categories = const [
    Category('tenda', 'Tenda'),
    Category('carrier', 'Carrier'),
    Category('sleeping-bag', 'Sleeping Bag'),
    Category('masak', 'Alat Masak'),
    Category('penerangan', 'Penerangan'),
    Category('sepatu', 'Sepatu'),
  ];

  static List<AssetPhoto> _photos(String name, int count) => [
        for (var i = 1; i <= count; i++) AssetPhoto('assets/equipment/${name}_$i.jpg'),
      ];

  final equipment = [
    Equipment(id: 'e-dome4', providerId: 'p-arjuna', categoryId: 'tenda', name: 'Tenda Dome 4 Orang', brand: 'Eiger', description: 'Tenda double layer, frame alumunium, tahan angin gunung. Cocok untuk rombongan 3-4 orang.', pricePerDay: 45000, depositAmount: 100000, stock: 3, capacityPerson: 4, weightGram: 3200, rating: 4.7, conditionScore: 88, photos: _photos('dome4', 3)),
    Equipment(id: 'e-carrier60', providerId: 'p-arjuna', categoryId: 'carrier', name: 'Carrier 60L', brand: 'Consina', description: 'Carrier 60 liter dengan back system adjustable dan rain cover.', pricePerDay: 35000, depositAmount: 75000, stock: 5, weightGram: 1800, rating: 4.6, conditionScore: 85, photos: _photos('carrier60', 3)),
    Equipment(id: 'e-sbpolar', providerId: 'p-arjuna', categoryId: 'sleeping-bag', name: 'Sleeping Bag Polar', brand: 'Rei', description: 'Sleeping bag bahan polar, suhu nyaman hingga 10°C.', pricePerDay: 15000, depositAmount: 30000, stock: 8, capacityPerson: 1, weightGram: 900, rating: 4.5, conditionScore: 80, photos: _photos('sbpolar', 3)),
    Equipment(id: 'e-kompor', providerId: 'p-arjuna', categoryId: 'masak', name: 'Kompor Portable + 1 Gas', brand: 'Kovea', description: 'Kompor lipat dengan pemantik otomatis, termasuk 1 tabung gas.', pricePerDay: 20000, depositAmount: 50000, stock: 4, weightGram: 450, rating: 4.4, conditionScore: 90, photos: _photos('kompor', 2)),
    Equipment(id: 'e-ul2p', providerId: 'p-semeru', categoryId: 'tenda', name: 'Tenda Ultralight 2 Orang', brand: 'Naturehike', description: 'Tenda ultralight 1,5 kg untuk pendakian cepat. Double wall, 20D nylon.', pricePerDay: 60000, depositAmount: 150000, stock: 2, capacityPerson: 2, weightGram: 1500, rating: 4.9, conditionScore: 95, photos: _photos('ul2p', 3)),
    Equipment(id: 'e-headlamp', providerId: 'p-semeru', categoryId: 'penerangan', name: 'Headlamp 300 Lumen', brand: 'Petzl', description: 'Headlamp baterai AAA, mode red light, tahan cipratan air.', pricePerDay: 10000, depositAmount: 25000, stock: 10, weightGram: 90, rating: 4.7, conditionScore: 92, photos: _photos('headlamp', 2)),
    Equipment(id: 'e-sepatu', providerId: 'p-semeru', categoryId: 'sepatu', name: 'Sepatu Hiking Waterproof', brand: 'Merrell', description: 'Sepatu mid-cut waterproof dengan sol Vibram. Pilih ukuran sesuai ukuran sepatu harian Anda.', pricePerDay: 40000, depositAmount: 100000, weightGram: 1100, rating: 4.6, conditionScore: 82, photos: _photos('sepatu', 3), sizes: const [SizeStock('39', 1), SizeStock('40', 2), SizeStock('41', 2), SizeStock('42', 2), SizeStock('43', 1), SizeStock('44', 1)]),
    Equipment(id: 'e-nesting', providerId: 'p-semeru', categoryId: 'masak', name: 'Nesting Cooking Set', brand: 'DS', description: 'Set panci & wajan alumunium untuk 2-3 orang.', pricePerDay: 15000, depositAmount: 30000, stock: 6, weightGram: 600, rating: 4.3, conditionScore: 78, photos: _photos('nesting', 3)),
    Equipment(id: 'e-family6', providerId: 'p-puncak', categoryId: 'tenda', name: 'Tenda Family 6 Orang', brand: 'Great Outdoor', description: 'Tenda besar untuk camping keluarga.', pricePerDay: 80000, depositAmount: 200000, stock: 2, capacityPerson: 6, weightGram: 6500, conditionScore: 90, photos: _photos('family6', 2)),
  ];

  List<Rental> rentals() {
    Rental r({
      required String id,
      required String invoice,
      required AppUser customer,
      required String equipmentId,
      required int qty,
      String? size,
      required int startOffset,
      required int endOffset,
      required RentalStatus status,
      required List<Guarantee> guarantees,
      required List<(RentalStatus?, RentalStatus, String)> history,
    }) {
      final e = equipment.firstWhere((x) => x.id == equipmentId);
      final p = providers().firstWhere((x) => x.id == e.providerId);
      // Transaksi yang masih berjalan dibuat "barusan" agar job otomatis
      // (kedaluwarsa 12 jam / belum bayar 24 jam) tidak langsung mengubahnya.
      final created = startOffset >= 0
          ? now.subtract(const Duration(hours: 2))
          : day(min(-1, startOffset - 2));
      return Rental(
        id: id,
        invoiceCode: invoice,
        customerId: customer.id,
        customerName: customer.name,
        providerId: p.id,
        providerName: p.businessName,
        equipmentId: e.id,
        equipmentName: e.name,
        categoryId: e.categoryId,
        qty: qty,
        size: size,
        photo: e.photos.firstOrNull,
        startDate: day(startOffset),
        endDate: day(endOffset),
        pricePerDaySnapshot: e.pricePerDay,
        depositSnapshot: e.depositAmount,
        status: status,
        guarantees: guarantees,
        createdAt: created,
        logs: [
          for (final (i, h) in history.indexed)
            StatusLog(from: h.$1, to: h.$2, actorName: h.$3, at: created.add(Duration(minutes: i * 20))),
        ],
      );
    }

    final budi = users[0];
    final rina = users[1];
    return [
      r(
        id: 'r-1', invoice: 'INV-DEMO-0001', customer: budi, equipmentId: 'e-dome4', qty: 1,
        startOffset: 3, endOffset: 5, status: RentalStatus.pendingConfirmation,
        guarantees: [Guarantee(id: 'g-1', type: GuaranteeType.ktp, holderName: budi.name, documentNumber: '3573011204020001')],
        history: [(null, RentalStatus.pendingConfirmation, budi.name)],
      ),
      r(
        id: 'r-2', invoice: 'INV-DEMO-0002', customer: rina, equipmentId: 'e-dome4', qty: 2,
        startOffset: 4, endOffset: 6, status: RentalStatus.awaitingPayment,
        guarantees: [Guarantee(id: 'g-2', type: GuaranteeType.ktp, holderName: rina.name, documentNumber: '3578014507030002', status: GuaranteeStatus.verified)],
        history: [(null, RentalStatus.pendingConfirmation, rina.name), (RentalStatus.pendingConfirmation, RentalStatus.awaitingPayment, 'Arjuna Outdoor')],
      ),
      r(
        id: 'r-3', invoice: 'INV-DEMO-0003', customer: rina, equipmentId: 'e-carrier60', qty: 2,
        startOffset: 1, endOffset: 2, status: RentalStatus.paid,
        guarantees: [Guarantee(id: 'g-3', type: GuaranteeType.sim, holderName: rina.name, documentNumber: '1203-0405-000123', status: GuaranteeStatus.verified)],
        history: [
          (null, RentalStatus.pendingConfirmation, rina.name),
          (RentalStatus.pendingConfirmation, RentalStatus.awaitingPayment, 'Arjuna Outdoor'),
          (RentalStatus.awaitingPayment, RentalStatus.paid, rina.name),
        ],
      ),
      r(
        id: 'r-4', invoice: 'INV-DEMO-0004', customer: budi, equipmentId: 'e-ul2p', qty: 1,
        startOffset: -2, endOffset: 1, status: RentalStatus.pickedUp,
        guarantees: [
          Guarantee(id: 'g-4', type: GuaranteeType.ktm, holderName: budi.name, documentNumber: '225150200111045', status: GuaranteeStatus.held)
            ..heldAt = day(-2),
        ],
        history: [
          (null, RentalStatus.pendingConfirmation, budi.name),
          (RentalStatus.pendingConfirmation, RentalStatus.awaitingPayment, 'Semeru Camp Rent'),
          (RentalStatus.awaitingPayment, RentalStatus.paid, budi.name),
          (RentalStatus.paid, RentalStatus.pickedUp, 'Semeru Camp Rent'),
        ],
      ),
      r(
        id: 'r-5', invoice: 'INV-DEMO-0005', customer: budi, equipmentId: 'e-sbpolar', qty: 2,
        startOffset: -10, endOffset: -8, status: RentalStatus.completed,
        guarantees: [
          Guarantee(id: 'g-5', type: GuaranteeType.ktp, holderName: budi.name, documentNumber: '3573011204020001', status: GuaranteeStatus.returned)
            ..heldAt = day(-10)
            ..returnedAt = day(-8),
        ],
        history: [
          (null, RentalStatus.pendingConfirmation, budi.name),
          (RentalStatus.pendingConfirmation, RentalStatus.awaitingPayment, 'Arjuna Outdoor'),
          (RentalStatus.awaitingPayment, RentalStatus.paid, budi.name),
          (RentalStatus.paid, RentalStatus.pickedUp, 'Arjuna Outdoor'),
          (RentalStatus.pickedUp, RentalStatus.returned, 'Arjuna Outdoor'),
          (RentalStatus.returned, RentalStatus.completed, 'Arjuna Outdoor'),
        ],
      ),
      // Sudah lewat tanggal selesai: job otomatis menandainya "Terlambat" saat aplikasi
      // dibuka, sehingga denda keterlambatan bisa didemokan.
      r(
        id: 'r-6', invoice: 'INV-DEMO-0006', customer: rina, equipmentId: 'e-headlamp', qty: 2,
        startOffset: -5, endOffset: -2, status: RentalStatus.pickedUp,
        guarantees: [
          Guarantee(id: 'g-6', type: GuaranteeType.ktp, holderName: rina.name, documentNumber: '3578014507030002', status: GuaranteeStatus.held)
            ..heldAt = day(-5),
        ],
        history: [
          (null, RentalStatus.pendingConfirmation, rina.name),
          (RentalStatus.pendingConfirmation, RentalStatus.awaitingPayment, 'Semeru Camp Rent'),
          (RentalStatus.awaitingPayment, RentalStatus.paid, rina.name),
          (RentalStatus.paid, RentalStatus.pickedUp, 'Semeru Camp Rent'),
        ],
      ),
    ];
  }
}
