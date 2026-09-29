import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';

import '../core/format.dart';
import '../domain/guarantee.dart';
import 'common.dart';
import 'photo_widgets.dart';

Color guaranteeColor(GuaranteeStatus s) => switch (s) {
      GuaranteeStatus.submitted => Colors.orange.shade800,
      GuaranteeStatus.verified => Colors.blue.shade700,
      GuaranteeStatus.rejected => Colors.red.shade700,
      GuaranteeStatus.held => Colors.deepPurple,
      GuaranteeStatus.returned => Colors.green.shade800,
    };

/// Kartu satu jaminan pada detail transaksi.
class GuaranteeTile extends StatelessWidget {
  const GuaranteeTile({super.key, required this.guarantee, this.actions = const []});

  final Guarantee guarantee;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final g = guarantee;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Photo(g),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${g.type.label} · ${g.maskedNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('a.n. ${g.holderName}',
                          style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 6),
                      Pill(g.status.label, color: guaranteeColor(g.status)),
                    ],
                  ),
                ),
              ],
            ),
            if (g.heldAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Diterima provider: ${tanggalJam(g.heldAt!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            if (g.returnedAt != null)
              Text('Dikembalikan: ${tanggalJam(g.returnedAt!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (g.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Catatan: ${g.note}', style: const TextStyle(fontSize: 12)),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [for (final a in actions) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a))]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.guarantee);
  final Guarantee guarantee;

  @override
  Widget build(BuildContext context) {
    final photo = guarantee.photo;
    final box = Container(
      width: 72,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? const Icon(Icons.badge_outlined, color: Colors.blueGrey)
          : Image.memory(photo, fit: BoxFit.cover, cacheWidth: 240),
    );
    if (photo == null) return box;
    // Layar penuh dengan zoom, agar nomor dokumen terbaca jelas.
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PhotoViewerScreen(photos: [MemoryPhoto(guarantee.id, photo)]),
        ),
      ),
      child: box,
    );
  }
}

/// Form satu jaminan di layar booking.
class GuaranteeForm extends StatefulWidget {
  const GuaranteeForm({
    super.key,
    required this.index,
    required this.draft,
    required this.acceptedTypes,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final GuaranteeDraft draft;
  final Set<GuaranteeType> acceptedTypes;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<GuaranteeForm> createState() => _GuaranteeFormState();
}

class _GuaranteeFormState extends State<GuaranteeForm> {
  late final _number = TextEditingController(text: widget.draft.documentNumber);
  late final _holder = TextEditingController(text: widget.draft.holderName);

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final bytes = await pickPhoto(context, title: 'Foto dokumen jaminan');
    if (bytes == null || !mounted) return;
    setState(() => widget.draft.photo = bytes);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final type = d.type;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Jaminan ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<GuaranteeType>(
              initialValue: type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Jenis dokumen'),
              items: [
                for (final t in GuaranteeType.values)
                  if (widget.acceptedTypes.contains(t))
                    DropdownMenuItem(
                      value: t,
                      child: Text(t.label == t.fullName ? t.label : '${t.label} — ${t.fullName}',
                          overflow: TextOverflow.ellipsis),
                    ),
              ],
              onChanged: (t) {
                setState(() {
                  d.type = t;
                  // Buang karakter non-angka bila jenis baru wajib angka.
                  if (t?.exactDigits != null) {
                    d.documentNumber = d.documentNumber.replaceAll(RegExp(r'\D'), '');
                    _number.text = d.documentNumber;
                  }
                });
                widget.onChanged();
              },
            ),
            if (type != null && type.isHardToReplace)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${type.label} sulit diurus ulang bila hilang. Serahkan hanya ke penyedia terverifikasi dan simpan bukti serah terima.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              keyboardType: type?.exactDigits != null ? TextInputType.number : TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                if (type?.exactDigits != null) ...[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(type!.exactDigits),
                ],
              ],
              decoration: InputDecoration(
                labelText: 'Nomor dokumen',
                helperText: type?.exactDigits != null
                    ? '${_number.text.length}/${type!.exactDigits} digit'
                    : null,
              ),
              onChanged: (v) {
                d.documentNumber = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _holder,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama pemilik dokumen',
                helperText: 'Harus sama dengan nama akun penyewa',
                helperMaxLines: 2,
              ),
              onChanged: (v) {
                d.holderName = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 12),
            if (d.photo != null)
              // contain: seluruh dokumen terlihat, tidak terpotong.
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(d.photo!, fit: BoxFit.contain, cacheWidth: 900),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: Icon(d.photo == null ? Icons.add_a_photo_outlined : Icons.cached),
              label: Text(d.photo == null ? 'Foto dokumen' : 'Ganti foto'),
            ),
          ],
        ),
      ),
    );
  }
}
