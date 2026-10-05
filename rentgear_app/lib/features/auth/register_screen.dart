import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Daftar akun baru sebagai penyewa atau penyedia. Setelah berhasil,
/// pengguna langsung masuk.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();
  final _address = TextEditingController();
  final _bankAccount = TextEditingController();

  UserRole _role = UserRole.customer;
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  // Aturan yang sama dengan `AuthController::register` di server.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phonePattern = RegExp(r'^\+?[0-9]{9,15}$');
  static const _minPassword = 8;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _city, _password, _businessName, _address, _bankAccount]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final provider = _role == UserRole.provider;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().register(RegisterRequest(
        role: _role,
        name: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
        phone: _phone.text.trim(),
        city: _city.text.trim(),
        businessName: provider ? _businessName.text.trim() : null,
        address: provider ? _address.text.trim() : null,
        bankAccount: provider ? _bankAccount.text.trim() : null,
      ));
      // Halaman utama sudah berganti di bawah layar ini.
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _role == UserRole.provider;
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
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
                    const Text('Daftar sebagai', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.customer,
                          icon: Icon(Icons.person_outline),
                          label: Text('Penyewa'),
                        ),
                        ButtonSegment(
                          value: UserRole.provider,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text('Penyedia'),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      provider
                          ? 'Penyedia menyewakan alat miliknya lewat toko di RentGear.'
                          : 'Penyewa mencari dan menyewa alat dari toko yang terverifikasi.',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SectionTitle('Data diri'),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama lengkap',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) => _emailPattern.hasMatch((v ?? '').trim())
                          ? null
                          : 'Isi email yang benar, misalnya nama@mail.com.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => _phonePattern.hasMatch((v ?? '').trim())
                          ? null
                          : 'Isi 9 sampai 15 angka, misalnya 081234567890.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _city,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Kota',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: provider ? TextInputAction.next : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
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
                    if (provider) ...[
                      const SectionTitle('Data toko'),
                      TextFormField(
                        controller: _businessName,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama toko',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Alamat toko',
                          prefixIcon: Icon(Icons.signpost_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankAccount,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Rekening tujuan transfer',
                          helperText: 'Contoh: BCA 1234567890 a.n. Nama Pemilik',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Toko baru diperiksa admin dulu. Alat tampil di katalog setelah '
                        'toko diverifikasi. Sesudah daftar, atur titik toko di peta lewat '
                        'Profil > Lokasi toko di peta.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Daftar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
