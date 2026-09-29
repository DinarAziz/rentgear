// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Penyimpanan data untuk build web: pakai `localStorage` browser karena
/// `dart:io`/`path_provider` tidak tersedia di web. Foto disimpan sebagai
/// base64 (localStorage sekitar 5-10 MB per origin, cukup untuk demo).
class LocalStore {
  static const _dataKey = 'rentgear_data';
  static const _photoPrefix = 'rentgear_photo_';

  static Future<LocalStore> open() async => LocalStore();

  html.Storage get _storage => html.window.localStorage;

  Map<String, dynamic>? read() {
    final raw = _storage[_dataKey];
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null; // data rusak: mulai lagi dari data awal
    }
  }

  void write(Map<String, dynamic> data) {
    _storage[_dataKey] = jsonEncode(data);
  }

  String savePhoto(String name, Uint8List bytes) {
    _storage['$_photoPrefix$name.jpg'] = base64Encode(bytes);
    return '$name.jpg';
  }

  Uint8List? loadPhoto(String? fileName) {
    if (fileName == null) return null;
    final raw = _storage['$_photoPrefix$fileName'];
    return raw == null ? null : base64Decode(raw);
  }

  void clear() {
    _storage.remove(_dataKey);
    _storage.keys.where((k) => k.startsWith(_photoPrefix)).toList().forEach(_storage.remove);
  }
}
