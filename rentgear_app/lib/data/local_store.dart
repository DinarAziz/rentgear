/// `dart:io`+`path_provider` di mobile/desktop, `localStorage` di web
/// (lihat local_store_web.dart) — path_provider tidak mendukung web sama sekali.
library;

export 'local_store_io.dart' if (dart.library.html) 'local_store_web.dart';
