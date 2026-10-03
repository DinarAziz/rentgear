import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/models.dart';
import 'config.dart';

/// Tombol "Masuk dengan Google". Aplikasi hanya mengambil ID token dari
/// Google; yang memeriksa token dan membuat sesi adalah server.
abstract final class GoogleAuth {
  /// Butuh server (untuk memeriksa token) dan client ID.
  static bool get available => apiUrl.isNotEmpty && googleClientId.isNotEmpty;

  /// Di web Google mewajibkan tombol buatannya sendiri; hasilnya datang
  /// lewat [idTokens], bukan dari [signIn].
  static bool get usesRenderedButton => kIsWeb;

  static Future<void>? _ready;

  static Future<void> ensureReady() =>
      _ready ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? googleClientId : null,
        // Di Android dan iOS, ID token dibuat untuk client ID web milik server.
        serverClientId: kIsWeb ? null : googleClientId,
      );

  /// ID token setiap kali pengguna berhasil memilih akun (dipakai di web).
  static Stream<String> get idTokens => GoogleSignIn
      .instance
      .authenticationEvents
      .where((e) => e is GoogleSignInAuthenticationEventSignIn)
      .map(
        (e) => (e as GoogleSignInAuthenticationEventSignIn)
            .user
            .authentication
            .idToken,
      )
      .where((token) => token != null)
      .cast<String>();

  /// Membuka pemilih akun Google. `null` bila pengguna membatalkan.
  static Future<String?> signIn() async {
    try {
      await ensureReady();
      // Lupakan akun sebelumnya supaya pemilih akun selalu muncul.
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AppException('GOOGLE_FAILED', _failed);
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AppException('GOOGLE_FAILED', '$_failed (${e.code.name})');
    }
  }

  static const _failed = 'Masuk dengan Google gagal. Coba lagi.';
}
