/// Diskon durasi sebuah toko. Penyedia yang menanggung diskon, jadi penyedia
/// yang mengaturnya; platform hanya memasang batas atas. Diskon hanya memotong
/// biaya sewa, tidak deposit. Tiap sewa menyimpan persen diskonnya saat
/// booking dibuat.
class DiscountPolicy {
  const DiscountPolicy({this.shortPercent = 0, this.longPercent = 0});

  /// Batas platform: diskon paling besar dari biaya sewa.
  static const maxPercent = 50;
  static const shortDays = 3;
  static const longDays = 7;

  /// Diskon untuk sewa minimal [shortDays] hari.
  final int shortPercent;

  /// Diskon untuk sewa minimal [longDays] hari.
  final int longPercent;

  bool get isEmpty => shortPercent == 0 && longPercent == 0;

  DiscountPolicy copyWith({int? shortPercent, int? longPercent}) =>
      DiscountPolicy(
        shortPercent: shortPercent ?? this.shortPercent,
        longPercent: longPercent ?? this.longPercent,
      );

  /// Pesan kesalahan, atau `null` bila diskon ini ada dalam batas platform.
  String? get error {
    final percents = [shortPercent, longPercent];
    if (percents.any((p) => p < 0 || p > maxPercent)) {
      return 'Diskon harus antara 0 dan $maxPercent persen biaya sewa.';
    }
    if (longPercent < shortPercent) {
      return 'Diskon sewa $longDays hari tidak boleh lebih kecil dari diskon $shortDays hari.';
    }
    return null;
  }

  int percentFor(int days) => days >= longDays
      ? longPercent
      : days >= shortDays
      ? shortPercent
      : 0;

  Map<String, dynamic> toJson() => {
    'shortPercent': shortPercent,
    'longPercent': longPercent,
  };

  /// Data lama dan toko yang belum mengatur apa pun tidak memberi diskon.
  factory DiscountPolicy.fromJson(Map<String, dynamic>? j) => DiscountPolicy(
    shortPercent: (j?['shortPercent'] as num?)?.toInt() ?? 0,
    longPercent: (j?['longPercent'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is DiscountPolicy &&
      other.shortPercent == shortPercent &&
      other.longPercent == longPercent;

  @override
  int get hashCode => Object.hash(shortPercent, longPercent);
}

/// Potongan dibulatkan ke rupiah terdekat, sama dengan `PriceCalculator::discount` di server.
double discountAmount(double subtotal, int percent) =>
    (subtotal * percent / 100).roundToDouble();
