import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Penyimpanan data di memori internal HP (folder dokumen aplikasi).
/// Data transaksi disimpan sebagai JSON, foto disimpan sebagai file terpisah
/// agar file JSON tetap kecil.
class LocalStore {
  LocalStore(this.root);

  final Directory root;

  static Future<LocalStore> open() async =>
      LocalStore(await getApplicationDocumentsDirectory());

  File get _dataFile => File('${root.path}/rentgear_data.json');
  Directory get _photoDir => Directory('${root.path}/photos');

  Map<String, dynamic>? read() {
    if (!_dataFile.existsSync()) return null;
    try {
      return jsonDecode(_dataFile.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      return null; // file rusak: mulai lagi dari data awal
    }
  }

  void write(Map<String, dynamic> data) {
    // Tulis ke file sementara lalu rename, agar data tidak setengah tertulis
    // bila aplikasi ditutup paksa.
    final tmp = File('${_dataFile.path}.tmp')..writeAsStringSync(jsonEncode(data), flush: true);
    tmp.renameSync(_dataFile.path);
  }

  /// Menyimpan foto sekali saja, mengembalikan nama file untuk JSON.
  String savePhoto(String name, Uint8List bytes) {
    _photoDir.createSync(recursive: true);
    final file = File('${_photoDir.path}/$name.jpg');
    if (!file.existsSync()) file.writeAsBytesSync(bytes, flush: true);
    return '$name.jpg';
  }

  Uint8List? loadPhoto(String? fileName) {
    if (fileName == null) return null;
    final file = File('${_photoDir.path}/$fileName');
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  void clear() {
    if (_dataFile.existsSync()) _dataFile.deleteSync();
    if (_photoDir.existsSync()) _photoDir.deleteSync(recursive: true);
  }
}
