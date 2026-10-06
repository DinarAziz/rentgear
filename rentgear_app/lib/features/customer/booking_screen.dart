import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../domain/availability.dart';
import '../../domain/guarantee.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/guarantee_widgets.dart';
import '../../widgets/photo_widgets.dart';
import '../rental/rental_detail_screen.dart';

/// Isian awal form booking dari saran AI: jumlah unit dan lama sewa.
class BookingPrefill {
  const BookingPrefill({required this.qty, required this.days});

  final int qty;
  final int days;
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.equipment, required this.provider, this.prefill});

  final Equipment equipment;
  final ProviderProfile provider;

  /// `null` bila form dibuka dari katalog biasa.
  final BookingPrefill? prefill;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // Satu key per layar: tombol ditekan dua kali tetap satu booking.
  final _idempotencyKey = DateTime.now().microsecondsSinceEpoch.toString();
  DateTimeRange? _range;
  String? _size;
  int _qty = 1;

  /// Sisa unit untuk pilihan saat ini (ukuran + tanggal). `null` = belum dicek.
  int? _available;

  /// Sisa unit per ukuran pada tanggal terpilih (alat berukuran saja).
  Map<String, int> _sizeAvailable = {};
  bool _checking = false;
  bool _agree = false;
  bool _submitting = false;
  bool _submitted = false;
  List<String> _errors = [];
  final List<GuaranteeDraft> _drafts = [];

  Equipment get e => widget.equipment;
  GuaranteePolicy get policy => widget.provider.policy;
  String get renterName => context.read<AppState>().currentUser.name;

  int get _days => _range == null ? 0 : inclusiveDays(_range!.start, _range!.end);
  double get _subtotal => e.pricePerDay * _qty * _days;
  double get _deposit => e.depositAmount * _qty;
  double get _total => _subtotal + _deposit;
  int get _required => policy.requiredCount(_total);

  /// Batas atas jumlah unit yang boleh dipilih.
  int get _maxQty {
    if (_available != null) return _available!;
    if (e.hasSizes) return _size == null ? 0 : e.stockFor(_size);
    return e.stockTotal;
  }

  /// Tanggal yang diisi otomatis dari saran AI; belum dihitung sebagai isian pengguna.
  DateTimeRange? _prefilledRange;

  bool get _dirty =>
      !_submitted &&
      (_range != _prefilledRange ||
          _size != null ||
          _drafts.any((d) => d.type != null || d.documentNumber.isNotEmpty || d.photo != null));

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      // Saran AI tidak memuat tanggal berangkat, jadi sewa dimulai besok selama jumlah hari yang diminta.
      final start = dateOnly(DateTime.now()).add(const Duration(days: 1));
      _qty = prefill.qty < 1 ? 1 : prefill.qty;
      _range = _prefilledRange = DateTimeRange(start: start, end: start.add(Duration(days: prefill.days - 1)));
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAvailability());
    }
    _syncDraftCount();
  }

  /// Tambah form jaminan otomatis bila jumlah minimal naik.
  void _syncDraftCount() {
    while (_drafts.length < _required) {
      _drafts.add(GuaranteeDraft(holderName: context.read<AppState>().currentUser.name));
    }
  }

  Future<void> _pickRange() async {
    dismissKeyboard();
    final today = dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      initialDateRange: _range,
      helpText: 'Pilih tanggal sewa',
      saveText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    await _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final range = _range;
    if (range == null) return;
    setState(() => _checking = true);
    final repo = context.read<AppState>().repo;
    try {
      if (e.hasSizes) {
        _sizeAvailable = await repo.sizeAvailability(e.id, range.start, range.end);
        _available = _size == null ? null : _sizeAvailable[_size];
      } else {
        _available = await repo.availableQty(e.id, range.start, range.end);
      }
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          final max = _maxQty;
          if (_qty > max) _qty = max < 1 ? 1 : max;
          _syncDraftCount();
        });
      }
    }
  }

  void _selectSize(String size) {
    setState(() {
      _size = size;
      _available = _range == null ? null : _sizeAvailable[size];
      final max = _maxQty;
      if (_qty > max) _qty = max < 1 ? 1 : max;
      _syncDraftCount();
    });
  }

  Future<void> _submit() async {
    final range = _range;
    final errors = <String>[
      if (range == null) 'Pilih tanggal sewa.',
      if (e.hasSizes && _size == null) 'Pilih ukuran.',
      if (_available != null && _qty > _available!) 'Stok tidak cukup untuk jumlah ini.',
      ...policy.validate(_drafts, rentalValue: _total, renterName: renterName),
      if (!_agree) 'Centang persetujuan jaminan di bawah.',
    ];
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _submitting = true);
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Rental? rental;
    String? failedCode;
    try {
      rental = await state.run((repo) => repo.createBooking(BookingRequest(
            customerId: state.currentUser.id,
            equipmentId: e.id,
            qty: _qty,
            size: _size,
            startDate: range!.start,
            endDate: range.end,
            guarantees: _drafts,
            idempotencyKey: _idempotencyKey,
          )));
    } on AppException catch (err) {
      failedCode = err.code;
      if (mounted) setState(() => _errors = err.message.split('\n'));
    } catch (err) {
      if (mounted) setState(() => _errors = ['Gagal mengirim booking: $err']);
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    // Stok bisa diambil orang lain saat form diisi: tampilkan angka terbaru.
    if (failedCode == 'SLOT_UNAVAILABLE') await _checkAvailability();
    if (rental == null) return;
    _submitted = true;
    messenger.showSnackBar(
      const SnackBar(content: Text('Booking terkirim. Menunggu konfirmasi penyedia.')),
    );
    navigator.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => RentalDetailScreen(rentalId: rental!.id),
    ));
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Batalkan pengisian?',
      message: 'Data booking dan foto jaminan yang sudah diisi akan hilang.',
      confirmLabel: 'Keluar',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = _available == 0;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Buat Booking')),
        body: ReadableListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Card(
              child: ListTile(
                leading: ItemThumb(photo: e.photos.firstOrNull, categoryId: e.categoryId, size: 48),
                title: Text(e.name),
                subtitle: Text('${widget.provider.businessName}\n${rupiah(e.pricePerDay)} /hari'),
                isThreeLine: true,
              ),
            ),
            SectionTitle(e.hasSizes ? '1. Tanggal, ukuran & jumlah' : '1. Tanggal & jumlah'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.prefill case final prefill?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Diisi dari saran AI: ${prefill.qty} unit selama ${prefill.days} hari, mulai besok. '
                          'Ubah tanggal atau jumlah bila perlu.',
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(_range == null
                          ? 'Pilih tanggal'
                          : '${rentangTanggal(_range!.start, _range!.end)} ($_days hari)'),
                    ),
                    if (e.hasSizes) ...[
                      const SizedBox(height: 14),
                      const Text('Ukuran', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _SizePicker(
                        sizes: e.sizes,
                        selected: _size,
                        available: _range == null ? null : _sizeAvailable,
                        onSelected: _selectSize,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Jumlah unit'),
                        const Spacer(),
                        IconButton.outlined(
                          tooltip: 'Kurangi',
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text('$_qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        IconButton.outlined(
                          tooltip: 'Tambah',
                          onPressed: _qty < _maxQty
                              ? () => setState(() {
                                    _qty++;
                                    _syncDraftCount();
                                  })
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    if (_checking)
                      const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator())
                    else if (_available != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          soldOut
                              ? 'Stok habis pada tanggal ini${_size == null ? '' : ' untuk ukuran $_size'}. Pilih tanggal lain.'
                              : 'Tersedia $_available unit${_size == null ? '' : ' ukuran $_size'} pada tanggal ini.',
                          style: TextStyle(color: soldOut ? Colors.red.shade700 : Colors.green.shade800),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SectionTitle(
              '2. Jaminan (wajib $_required)',
              trailing: _drafts.length < GuaranteePolicy.maxPerBooking
                  ? TextButton.icon(
                      onPressed: () => setState(() => _drafts.add(GuaranteeDraft(holderName: renterName))),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah'),
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Diterima: ${[for (final t in GuaranteeType.values) if (policy.acceptedTypes.contains(t)) t.label].join(', ')}. '
                'Foto dokumen diperiksa penyedia; dokumen asli diserahkan saat mengambil alat '
                'dan dikembalikan saat alat kembali.',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
            for (final (i, d) in _drafts.indexed) ...[
              GuaranteeForm(
                key: ObjectKey(d),
                index: i,
                draft: d,
                acceptedTypes: policy.acceptedTypes,
                onChanged: () => setState(() {}),
                onRemove: _drafts.length > _required ? () => setState(() => _drafts.remove(d)) : null,
              ),
              const SizedBox(height: 10),
            ],
            const SectionTitle('3. Ringkasan biaya'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _range == null
                    ? const Text('Pilih tanggal untuk melihat total biaya.',
                        style: TextStyle(color: Colors.black54))
                    : Column(
                        children: [
                          InfoRow('Sewa ${rupiah(e.pricePerDay)} × $_qty unit × $_days hari', rupiah(_subtotal)),
                          InfoRow('Deposit (uang jaminan)', rupiah(_deposit)),
                          const Divider(),
                          InfoRow('Total dibayar', rupiah(_total), bold: true),
                          const DepositNote(),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Saya setuju menyerahkan dokumen asli jaminan saat pengambilan alat. '
                'Dokumen dikembalikan setelah alat kembali dalam kondisi baik.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_errors.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final err in _errors)
                      Text('• $err', style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting || soldOut || _checking ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kirim Booking'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SizePicker extends StatelessWidget {
  const _SizePicker({
    required this.sizes,
    required this.selected,
    required this.available,
    required this.onSelected,
  });

  final List<SizeStock> sizes;
  final String? selected;

  /// `null` = tanggal belum dipilih, tampilkan stok total per ukuran.
  final Map<String, int>? available;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in sizes)
            Builder(builder: (context) {
              final left = available == null ? s.stock : (available![s.label] ?? 0);
              return ChoiceChip(
                showCheckmark: false,
                selected: selected == s.label,
                onSelected: left > 0 ? (_) => onSelected(s.label) : null,
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(left > 0 ? (available == null ? 'stok $left' : 'sisa $left') : 'habis',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
        ],
      );
}
