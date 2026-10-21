import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';

/// Penyewa membuka toko. Akunnya menjadi akun penyedia, lalu toko menunggu
/// dokumen verifikasi. Dipakai juga oleh akun dari Google, yang selalu mulai
/// sebagai penyewa.
class OpenStoreScreen extends StatefulWidget {
  const OpenStoreScreen({super.key});

  @override
  State<OpenStoreScreen> createState() => _OpenStoreScreenState();
}

class _OpenStoreScreenState extends State<OpenStoreScreen> {
  final _form = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _address = TextEditingController();
  final _bankAccount = TextEditingController();
  late final _phone = TextEditingController(
    text: context.read<AppState>().currentUser.phone,
  );
  late final _city = TextEditingController(
    text: context.read<AppState>().currentUser.city,
  );
  bool _sending = false;
  String? _error;

  // Aturan yang sama dengan `StoreVerificationController::open` di server.
  static final _phonePattern = RegExp(r'^\+?[0-9]{9,15}$');

  @override
  void dispose() {
    for (final c in [_businessName, _address, _bankAccount, _phone, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await confirmDialog(
      context,
      title: 'Jadikan akun ini akun penyedia?',
      message:
          'Setelah toko dibuka, akun ini dipakai untuk mengelola toko dan tidak bisa menyewa alat. '
          'Riwayat sewa Anda tetap tersimpan di server.',
      confirmLabel: 'Buka toko',
    );
    if (!ok || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<AppState>().openStore(
        OpenStoreRequest(
          businessName: _businessName.text.trim(),
          address: _address.text.trim(),
          bankAccount: _bankAccount.text.trim(),
          phone: _phone.text.trim(),
          city: _city.text.trim(),
        ),
      );
      // Halaman utama sudah berganti menjadi halaman penyedia di bawah layar ini.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Toko dibuat. Kirim dokumen verifikasi lewat Profil > Verifikasi toko.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buka Toko')),
    body: Form(
      key: _form,
      child: ReadableListView(
        maxWidth: 480,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Sewakan alat hiking Anda lewat RentGear. Setelah toko dibuat, kirim foto KTP, swafoto '
            'dengan KTP, dan foto toko. Alat tampil di katalog setelah admin memverifikasi toko.',
            style: TextStyle(color: Colors.black54),
          ),
          const SectionTitle('Data toko'),
          TextFormField(
            controller: _businessName,
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
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Alamat toko',
              prefixIcon: Icon(Icons.signpost_outlined),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Kota',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankAccount,
            decoration: const InputDecoration(
              labelText: 'Rekening tujuan transfer',
              helperText: 'Contoh: BCA 1234567890 a.n. Nama Pemilik',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor HP',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) => _phonePattern.hasMatch((v ?? '').trim())
                ? null
                : 'Isi 9 sampai 15 angka, misalnya 081234567890.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Buka toko'),
          ),
        ],
      ),
    ),
  );
}
