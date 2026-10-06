import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/google_auth.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/local_repository.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/google_button.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _demo = [
    ('Penyewa · Budi', 'budi@rentgear.id', Icons.person_outline),
    ('Penyedia · Arjuna', 'sari@rentgear.id', Icons.storefront_outlined),
    ('Penyedia · Semeru', 'dewi@rentgear.id', Icons.storefront_outlined),
    ('Admin', 'admin@rentgear.id', Icons.admin_panel_settings_outlined),
  ];

  StreamSubscription<String>? _googleTokens;

  @override
  void initState() {
    super.initState();
    // Di web, hasil tombol Google datang lewat stream.
    if (GoogleAuth.available && GoogleAuth.usesRenderedButton) {
      GoogleAuth.ensureReady().then((_) {
        if (!mounted) return;
        setState(() {
          _googleTokens = GoogleAuth.idTokens.listen(
            (token) => _run((state) => state.loginWithGoogle(token)),
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _googleTokens?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AppState state) action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action(context.read<AppState>());
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() =>
      _run((state) => state.login(_email.text, _password.text));

  Future<void> _loginWithGoogle() => _run((state) async {
    final token = await GoogleAuth.signIn();
    if (token != null) await state.loginWithGoogle(token);
  });

  @override
  Widget build(BuildContext context) {
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _form(context),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: switch (FormFactor.of(context)) {
          FormFactor.phone => form,
          // Tablet: form di dalam kartu di atas latar berwarna.
          FormFactor.tablet => ColoredBox(
            color: AppColors.forest.withValues(alpha: 0.08),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _form(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Desktop: panel merek di kiri, form di kanan.
          FormFactor.desktop => Row(
            children: [
              const Expanded(child: _BrandPanel()),
              Expanded(child: form),
            ],
          ),
        },
      ),
    );
  }

  Widget _form(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.landscape_rounded, size: 64, color: AppColors.forest),
      const SizedBox(height: 8),
      Text(
        'RentGear',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.forest,
        ),
      ),
      const Text(
        'Sewa alat hiking & camping, aman dan terverifikasi',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: true,
        textInputAction: TextInputAction.go,
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        onSubmitted: (_) => _login(),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Masuk'),
      ),
      if (GoogleAuth.available) ...[
        const SizedBox(height: 12),
        if (!GoogleAuth.usesRenderedButton)
          OutlinedButton.icon(
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Masuk dengan Google'),
            onPressed: _loading ? null : _loginWithGoogle,
          )
        else if (_googleTokens != null)
          Center(child: googleRenderedButton()),
        const SizedBox(height: 6),
        const Text(
          'Akun Google baru terdaftar sebagai penyewa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
      // Akun baru dan kode ganti password ada di server, jadi tidak ada di mode data lokal.
      if (context.read<AppState>().repo.isRemote) ...[
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
          child: const Text('Belum punya akun? Daftar'),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordScreen(email: _email.text.trim()),
                  ),
                ),
          child: const Text('Lupa password?'),
        ),
      ],
      const SizedBox(height: 32),
      const Text(
        'Akun demo (password: password)',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (label, email, icon) in _demo)
            // Di server publik (https) admin masuk dengan passwordnya sendiri.
            if (!(apiUrl.startsWith('https://') && email.startsWith('admin@')))
              ActionChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                onPressed: () {
                  _email.text = email;
                  _password.text = LocalRentGearRepository.demoPassword;
                  _login();
                },
              ),
        ],
      ),
    ],
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _points = [
    (Icons.verified_user_outlined, 'Penyedia terverifikasi admin'),
    (Icons.badge_outlined, 'Jaminan dokumen tercatat dan dikembalikan'),
    (Icons.event_available_outlined, 'Stok dicek per tanggal, tanpa bentrok'),
  ];

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.forest,
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.landscape_rounded, size: 72, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Naik gunung tanpa\nbeli semua alat.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sewa tenda, carrier, sepatu, dan alat masak dari penyedia lokal.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 32),
          for (final (icon, text) in _points)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
