import 'package:flutter/foundation.dart';

import '../data/local_repository.dart';
import '../data/repository.dart';
import '../domain/models.dart';

/// State global: sesi login + penanda revisi data.
/// Setiap aksi yang mengubah data lewat [run], lalu [revision] naik
/// sehingga semua [AsyncView] memuat ulang datanya.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final RentGearRepository repo;
  AppUser? _user;
  int _revision = 0;

  AppUser? get user => _user;
  AppUser get currentUser => _user!;
  int get revision => _revision;

  /// Dipanggil sekali saat aplikasi dibuka: pulihkan sesi + jalankan job.
  Future<void> bootstrap() async {
    await repo.runScheduledJobs();
    _user = await repo.restoreSession();
  }

  /// Dipanggil saat aplikasi kembali ke depan (resume).
  Future<void> refresh() async {
    final changed = await repo.runScheduledJobs();
    if (changed > 0) {
      _revision++;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _user = await repo.login(email, password);
    await repo.runScheduledJobs();
    _revision++;
    notifyListeners();
  }

  Future<void> logout() async {
    await repo.logout();
    _user = null;
    notifyListeners();
  }

  bool get canResetDemo => repo is LocalRentGearRepository;

  /// Hapus semua data di HP dan kembali ke data demo awal.
  Future<void> resetDemo() async {
    await (repo as LocalRentGearRepository).resetDemoData();
    _user = null;
    _revision++;
    notifyListeners();
  }

  Future<T> run<T>(Future<T> Function(RentGearRepository repo) action) async {
    final result = await action(repo);
    _revision++;
    notifyListeners();
    return result;
  }
}
