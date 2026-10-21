import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';
import '../../widgets/verification_widgets.dart';

/// Penyedia mengirim data toko dan dokumen verifikasi, lalu melihat hasil
/// pemeriksaan admin. Toko yang ditolak memperbaiki dan mengirim ulang di sini.
class StoreVerificationScreen extends StatelessWidget {
  const StoreVerificationScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Toko')),
      body: AsyncView<(ProviderProfile, StoreVerification)>(
        load: () async => (
          await state.repo.provider(providerId),
          await state.repo.storeVerification(providerId, state.currentUser),
        ),
        builder: (context, data) =>
            _Body(provider: data.$1, verification: data.$2),
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.provider, required this.verification});

  final ProviderProfile provider;
  final StoreVerification verification;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _form = GlobalKey<FormState>();
  late final _businessName = TextEditingController(
    text: widget.provider.businessName,
  );
  late final _address = TextEditingController(text: widget.provider.address);
  late final _bankAccount = TextEditingController(
    text: widget.provider.bankAccount ?? '',
  );
  final _nik = TextEditingController();
  Uint8List? _ktp;
  Uint8List? _selfie;
  List<Uint8List> _storePhotos = [];
  bool _resend = false;
  bool _sending = false;

  @override
  void dispose() {
    for (final c in [_businessName, _address, _bankAccount, _nik]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _pick(String title, void Function(Uint8List bytes) use) async {
    final bytes = await pickPhoto(context, title: title);
    if (bytes != null) setState(() => use(bytes));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final request = VerificationRequest(
      businessName: _businessName.text,
      address: _address.text,
      bankAccount: _bankAccount.text,
      nik: _nik.text,
      ktpPhoto: _ktp,
      selfiePhoto: _selfie,
      storePhotos: _storePhotos,
    );
    final state = context.read<AppState>();
    setState(() => _sending = true);
    final ok = await runAction(
      context,
      () => state.run(
        (repo) => repo.submitVerification(
          widget.provider.id,
          state.currentUser,
          request,
        ),
      ),
      success: 'Dokumen terkirim. Admin akan memeriksanya.',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.verification;
    final showForm =
        v.status != ProviderStatus.verified &&
        (!v.submitted || v.status == ProviderStatus.rejected || _resend);
    return ReadableListView(
      maxWidth: 640,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        VerificationStatusCard(v, forAdmin: false),
        if (v.submitted && !showForm) ...[
          const SectionTitle('Dokumen yang dikirim'),
          if (v.nikMasked case final nik?) InfoRow('NIK', nik),
          const SizedBox(height: 8),
          DocumentPhotos(v),
          if (v.status == ProviderStatus.pending) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _resend = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Ganti data atau dokumen'),
            ),
          ],
        ],
        if (showForm) _buildForm(),
      ],
    );
  }

  Widget _buildForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          controller: _bankAccount,
          decoration: const InputDecoration(
            labelText: 'Rekening tujuan transfer',
            helperText:
                'Nama pemilik rekening sebaiknya sama dengan nama di KTP.',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          validator: _required,
        ),
        const SectionTitle('Identitas pemilik'),
        TextFormField(
          controller: _nik,
          keyboardType: TextInputType.number,
          maxLength: 16,
          decoration: const InputDecoration(
            labelText: 'NIK di KTP',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (value) =>
              VerificationRequest.nikPattern.hasMatch(
                (value ?? '').replaceAll(' ', ''),
              )
              ? null
              : 'NIK harus 16 angka.',
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Slot(
              label: 'Foto KTP',
              photo: _ktp,
              onPick: () => _pick('Foto KTP', (bytes) => _ktp = bytes),
            ),
            _Slot(
              label: 'Swafoto dengan KTP',
              photo: _selfie,
              onPick: () => _pick(
                'Foto diri sambil memegang KTP',
                (bytes) => _selfie = bytes,
              ),
            ),
          ],
        ),
        SectionTitle(
          'Foto toko atau stok alat (${_storePhotos.length}/${VerificationRequest.maxStorePhotos})',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, photo) in _storePhotos.indexed)
              _Slot(
                label: 'Foto ${i + 1}',
                photo: photo,
                onRemove: () => setState(
                  () => _storePhotos = [..._storePhotos]..removeAt(i),
                ),
              ),
            if (_storePhotos.length < VerificationRequest.maxStorePhotos)
              AddPhotoTile(
                onTap: () => _pick(
                  'Foto toko atau stok alat',
                  (bytes) => _storePhotos = [..._storePhotos, bytes],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'NIK disimpan terenkripsi dan hanya tampil tersamar. Foto dokumen hanya bisa dilihat '
          'Anda dan admin RentGear, tidak tampil di halaman toko.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
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
              : const Text('Kirim untuk diverifikasi'),
        ),
      ],
    ),
  );
}

/// Satu kotak foto dokumen: tambah bila kosong, ganti atau hapus bila terisi.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.photo,
    this.onPick,
    this.onRemove,
  });

  final String label;
  final Uint8List? photo;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = photo;
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes == null)
            AddPhotoTile(onTap: onPick ?? () {}, size: 104)
          else
            Stack(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onPick,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      cacheWidth: 320,
                    ),
                  ),
                ),
                if (onRemove != null)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      tooltip: 'Hapus foto',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onRemove,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
