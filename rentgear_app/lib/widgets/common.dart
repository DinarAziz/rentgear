
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../state/app_state.dart';
import 'motion.dart';
import 'photo_widgets.dart';

/// Memuat data async dan otomatis memuat ulang saat [AppState.revision] naik
/// atau saat [deps] berubah (mis. kata kunci cari). Data lama tetap tampil
/// selama memuat ulang, jadi layar tidak berkedip.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.deps,
    this.frame,
  });

  final Future<T> Function() load;
  final Object? deps;
  final Widget Function(BuildContext context, T data) builder;

  /// Pembungkus untuk tampilan memuat dan galat, bila [builder] membuat
  /// Scaffold sendiri dan AsyncView ini tidak berada di dalam Scaffold.
  final Widget Function(Widget child)? frame;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  Future<T>? _future;
  int? _revision;
  T? _last;

  @override
  void didUpdateWidget(covariant AsyncView<T> old) {
    super.didUpdateWidget(old);
    if (old.deps != widget.deps) _future = null;
  }

  @override
  Widget build(BuildContext context) {
    final revision = context.select<AppState, int>((s) => s.revision);
    if (_future == null || revision != _revision) {
      _revision = revision;
      _future = widget.load();
    }
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        final frame = widget.frame ?? (child) => child;
        if (snap.hasError) {
          return frame(
            EmptyState(
              icon: Icons.error_outline,
              message: snap.error.toString(),
              action: TextButton(
                onPressed: () => setState(() => _future = widget.load()),
                child: const Text('Coba lagi'),
              ),
            ),
          );
        }
        if (snap.hasData) _last = snap.data;
        // Saat memuat ulang, tetap tampilkan data lama agar layar tidak berkedip.
        final data = snap.hasData ? snap.data : _last;
        if (data == null) {
          return frame(const Center(child: CircularProgressIndicator()));
        }
        return widget.builder(context, data);
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}

const categoryIcons = <String, IconData>{
  'tenda': Icons.holiday_village_outlined,
  'carrier': Icons.backpack_outlined,
  'sleeping-bag': Icons.bed_outlined,
  'masak': Icons.outdoor_grill_outlined,
  'penerangan': Icons.flashlight_on_outlined,
  'sepatu': Icons.hiking,
  'perlengkapan': Icons.inventory_2_outlined,
};

class EquipmentThumb extends StatelessWidget {
  const EquipmentThumb({super.key, required this.categoryId, this.size = 64});

  final String categoryId;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.forest.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(size / 5),
    ),
    child: Icon(
      categoryIcons[categoryId] ?? Icons.terrain,
      color: AppColors.forest,
      size: size * 0.5,
    ),
  );
}

Color statusColor(RentalStatus s) => switch (s) {
  RentalStatus.pendingConfirmation ||
  RentalStatus.awaitingPayment => Colors.orange.shade800,
  RentalStatus.paid => Colors.blue.shade700,
  RentalStatus.pickedUp => AppColors.forest,
  RentalStatus.overdue || RentalStatus.disputed => Colors.red.shade700,
  RentalStatus.returned => Colors.teal.shade700,
  RentalStatus.completed => Colors.green.shade800,
  _ => Colors.grey.shade700,
};

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final RentalStatus status;

  @override
  Widget build(BuildContext context) => StatusCrossfade(
    value: status,
    child: Pill(status.label, color: statusColor(status)),
  );
}

/// Penjelasan singkat deposit, dipasang di bawah baris "Deposit (uang jaminan)".
class DepositNote extends StatelessWidget {
  const DepositNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.black54),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Deposit bukan biaya sewa. Uang ini kembali penuh setelah alat '
              'dipulangkan tepat waktu dan utuh. Kalau terlambat atau rusak, '
              'dipotong denda dulu.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          // Nilai rata kanan dan boleh memakai sampai 60% lebar baris.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.5,
            ),
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class RentalCard extends StatelessWidget {
  const RentalCard({
    super.key,
    required this.rental,
    required this.onTap,
    this.showCustomer = false,
  });

  final Rental rental;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    const muted = TextStyle(color: Colors.black54, fontSize: 13);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ItemThumb(photo: r.photo, categoryId: r.categoryId, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.itemLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          showCustomer ? r.customerName : r.providerName,
                          style: muted,
                        ),
                        Text(
                          rentangTanggal(r.startDate, r.endDate),
                          style: muted,
                        ),
                        Text(
                          r.invoiceCode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(r.status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rupiah(r.grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menjalankan aksi, menampilkan SnackBar sukses atau pesan error.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on AppException catch (e) {
    _showError(messenger, e.message);
    return false;
  } catch (e) {
    // Kesalahan tak terduga (file, plugin kamera, dll.) tetap dilaporkan.
    _showError(messenger, 'Terjadi kesalahan: $e');
    return false;
  }
}

void _showError(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
  );

/// Minta pengguna memilih kamera atau galeri, lalu kembalikan bytes foto.
/// `null` bila dibatalkan. Foto diperkecil agar hemat memori & penyimpanan.
Future<Uint8List?> pickPhoto(
  BuildContext context, {
  String title = 'Tambah foto',
}) async {
  dismissKeyboard();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil dengan kamera'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari galeri'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  if (!context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await _pickFrom(source);
  } on PlatformException catch (e) {
    // HP tanpa aplikasi kamera yang melayani aplikasi lain (kamera bawaan
    // dihapus atau diganti): beri tahu, lalu buka galeri sebagai gantinya.
    if (source == ImageSource.camera && e.code == 'no_available_camera') {
      _showError(messenger, noCameraMessage);
      try {
        return await _pickFrom(ImageSource.gallery);
      } catch (_) {
        return null;
      }
    }
    _showError(messenger, _pickErrorMessage(source, e.message ?? e.code));
    return null;
  } catch (e) {
    _showError(messenger, _pickErrorMessage(source, '$e'));
    return null;
  }
}

const noCameraMessage =
    'HP ini tidak punya aplikasi kamera yang bisa dipakai aplikasi lain. '
    'Pilih foto dari galeri.';

String _pickErrorMessage(ImageSource source, String detail) =>
    source == ImageSource.camera
    ? 'Kamera tidak bisa dibuka: $detail'
    : 'Galeri tidak bisa dibuka: $detail';

Future<Uint8List?> _pickFrom(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 80,
  );
  return file == null ? null : await file.readAsBytes();
}

/// Tutup keyboard sebelum membuka dialog/halaman lain, agar fokus kolom
/// teks tidak kembali lagi (keyboard muncul sendiri) setelah dialog ditutup.
void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya, lanjutkan',
}) async {
  dismissKeyboard();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> askReason(
  BuildContext context, {
  required String title,
  String hint = 'Alasan',
  String initial = '',
}) {
  dismissKeyboard();
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final text = value.text.trim();
            return FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: text.isEmpty
                  ? null
                  : () => Navigator.pop(context, text),
              child: const Text('Kirim'),
            );
          },
        ),
      ],
    ),
  );
}

/// Catatan di bawah setiap jawaban AI.
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.auto_awesome, size: 16, color: Colors.black45),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          'Dibuat AI, bisa keliru. Ini saran, bukan keputusan.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    ],
  );
}

/// Dialog yang memuat satu jawaban AI lalu menampilkannya lewat [builder].
/// Galat (AI mati, bukan mode server) tampil sebagai pesan di dialog.
Future<void> showAiDialog<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function() load,
  required List<Widget> Function(BuildContext context, T data) builder,
}) {
  dismissKeyboard();
  final future = load();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: FutureBuilder<T>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) {
            final error = snap.error;
            return Text(
              error is AppException
                  ? error.message
                  : 'Terjadi kesalahan: $error',
              style: TextStyle(color: Colors.red.shade700),
            );
          }
          if (!snap.hasData) {
            return const Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 14),
                Expanded(child: Text('AI sedang menilai…')),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...builder(context, snap.data as T),
                const SizedBox(height: 12),
                const AiDisclaimer(),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}
