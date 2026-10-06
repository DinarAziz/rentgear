import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';

/// Lupa password. Langkah 1: minta kode 6 angka ke email. Langkah 2: isi kode
/// dan password baru. Setelah berhasil, pengguna langsung masuk.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  /// Email yang sudah diketik di layar masuk.
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();

  bool _codeSent = false;
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  // Aturan yang sama dengan `AuthController` dan `PasswordResetService` di server.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _codeLength = 6;
  static const _minPassword = 8;

  String get _address => _email.text.trim().toLowerCase();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
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

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    await _run((state) async {
      await state.repo.requestPasswordReset(_address);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _resend() => _run((state) async {
    await state.repo.requestPasswordReset(_address);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode baru dikirim. Kode lama tidak berlaku lagi.')),
    );
  });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _run((state) async {
      await state.resetPassword(email: _address, code: _code.text, password: _password.text);
      // Halaman utama sudah berganti di bawah layar ini.
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lupa Password')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _codeSent
                        ? 'Jika $_address terdaftar, kode $_codeLength angka sudah dikirim ke sana. '
                              'Periksa kotak masuk dan folder Spam. Kode berlaku 15 menit.'
                        : 'Isi email akun Anda. Kami kirim kode $_codeLength angka untuk membuat password baru.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                        ? null
                        : 'Isi email yang benar, misalnya nama@mail.com.',
                    onFieldSubmitted: (_) => _sendCode(),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_codeLength),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kode dari email',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (v) => (v ?? '').length == _codeLength
                          ? null
                          : 'Isi $_codeLength angka dari email.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password baru',
                        helperText: 'Minimal $_minPassword karakter',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Sembunyikan password' : 'Lihat password',
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < _minPassword
                          ? 'Password minimal $_minPassword karakter.'
                          : null,
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : (_codeSent ? _save : _sendCode),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_codeSent ? 'Simpan password baru' : 'Kirim kode'),
                  ),
                  if (_codeSent) ...[
                    TextButton(
                      onPressed: _loading ? null : _resend,
                      child: const Text('Kirim ulang kode'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _codeSent = false;
                              _error = null;
                            }),
                      child: const Text('Ganti email'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
