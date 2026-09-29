import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../domain/equipment_rules.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_widgets.dart';

/// Tambah alat baru ([initial] `null`) atau ubah alat milik penyedia.
class EquipmentFormScreen extends StatefulWidget {
  const EquipmentFormScreen({super.key, this.initial});

  final Equipment? initial;

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _SizeRow {
  _SizeRow(String label, this.stock) : label = TextEditingController(text: label);

  final TextEditingController label;
  int stock;
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  late final Equipment? _initial = widget.initial;
  late final _name = TextEditingController(text: _initial?.name);
  late final _brand = TextEditingController(text: _initial?.brand);
  late final _description = TextEditingController(text: _initial?.description);
  late final _price = TextEditingController(text: _money(_initial?.pricePerDay));
  late final _deposit = TextEditingController(text: _money(_initial?.depositAmount));
  late final _weight = TextEditingController(text: _num(_initial?.weightGram));
  late final _capacity = TextEditingController(text: _num(_initial?.capacityPerson));
  late List<ItemPhoto> _photos = [...?_initial?.photos];
  late String _categoryId = _initial?.categoryId ?? 'tenda';
  late int _stock = _initial == null || _initial.hasSizes ? 1 : _initial.stock;
  late bool _useSizes = _initial?.hasSizes ?? false;
  late final List<_SizeRow> _sizes = [
    for (final s in _initial?.sizes ?? const <SizeStock>[]) _SizeRow(s.label, s.stock),
  ];
  late bool _active = _initial?.isActive ?? true;
  bool _saving = false;
  bool _saved = false;
  bool _touched = false;
  List<String> _errors = [];

  static String _num(num? v) => v == null ? '' : v.toStringAsFixed(0);
  static String _money(num? v) => v == null ? '' : ribuan(v);

  bool get _forceSizes => sizedCategories.contains(_categoryId);

  List<TextEditingController> get _fields =>
      [_name, _brand, _description, _price, _deposit, _weight, _capacity];

  @override
  void initState() {
    super.initState();
    // TextField bukan FormField, jadi tandai "sudah diubah" lewat listener.
    for (final c in _fields) {
      c.addListener(_touch);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _description, _price, _deposit, _weight, _capacity]) {
      c.dispose();
    }
    for (final r in _sizes) {
      r.label.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_touched) setState(() => _touched = true);
  }

  Equipment _draft() {
    final sizes = _useSizes || _forceSizes
        ? sortSizes([for (final r in _sizes) SizeStock(r.label.text.trim(), r.stock)])
        : const <SizeStock>[];
    return Equipment(
      id: _initial?.id ?? '',
      providerId: _initial?.providerId ?? '',
      categoryId: _categoryId,
      name: _name.text,
      brand: _brand.text,
      description: _description.text,
      pricePerDay: parseRibuan(_price.text) ?? 0,
      depositAmount: parseRibuan(_deposit.text) ?? 0,
      weightGram: int.tryParse(_weight.text) ?? 0,
      capacityPerson: int.tryParse(_capacity.text),
      stock: sizes.isEmpty ? _stock : 0,
      sizes: sizes,
      photos: _photos,
      isActive: _active,
    );
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= maxEquipmentPhotos) return;
    final bytes = await pickPhoto(context, title: 'Foto alat');
    if (bytes == null || !mounted) return;
    setState(() {
      _photos = [..._photos, MemoryPhoto('eq-${DateTime.now().microsecondsSinceEpoch}', bytes)];
      _touched = true;
    });
  }

  void _photoMenu(int index) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Lihat'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => PhotoViewerScreen(photos: _photos, initialIndex: index),
                  ),
                );
              },
            ),
            if (index > 0)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Jadikan foto utama'),
                onTap: () {
                  Navigator.pop(sheet);
                  setState(() {
                    final p = _photos[index];
                    _photos = [p, ..._photos.where((x) => !identical(x, p))];
                    _touched = true;
                  });
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Hapus foto', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(sheet);
                setState(() {
                  _photos = [..._photos]..removeAt(index);
                  _touched = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final draft = _draft();
    final errors = validateEquipment(draft);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    final ok = await runAction(
      context,
      () => state.run((repo) => repo.saveEquipment(draft, state.currentUser)),
      success: _initial == null ? 'Alat ditambahkan.' : 'Perubahan disimpan.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _saved = true;
      navigator.pop();
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Buang perubahan?',
      message: 'Perubahan yang belum disimpan akan hilang.',
      confirmLabel: 'Buang',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final showSizes = _useSizes || _forceSizes;

    return PopScope(
      canPop: !_touched || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_initial == null ? 'Tambah Alat' : 'Ubah Alat')),
        body: Form(
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              SectionTitle('Foto (${_photos.length}/$maxEquipmentPhotos)'),
              const Text('Foto pertama tampil di katalog. Ketuk foto untuk lihat, jadikan utama, atau hapus.',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (i, p) in _photos.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _photoMenu(i),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: ItemPhotoView(p, decodeWidth: 480),
                                ),
                              ),
                              if (i == 0)
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text('Utama',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_photos.length < maxEquipmentPhotos) AddPhotoTile(onTap: _addPhoto),
                  ],
                ),
              ),
              const SectionTitle('Informasi alat'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama alat', hintText: 'Mis. Tenda Dome 4 Orang'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Merek'),
              ),
              const SizedBox(height: 12),
              AsyncView<List<Category>>(
                load: state.repo.categories,
                builder: (context, cats) => DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() {
                    _categoryId = v ?? _categoryId;
                    if (_forceSizes && _sizes.isEmpty) _sizes.add(_SizeRow('', 1));
                  }),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Deskripsi', alignLabelWithHint: true),
              ),
              const SectionTitle('Harga'),
              _fieldPair(
                context,
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Sewa per hari', prefixText: 'Rp '),
                ),
                TextField(
                  controller: _deposit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RibuanInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Deposit / unit', prefixText: 'Rp '),
                ),
              ),
              const SectionTitle('Spesifikasi'),
              _fieldPair(
                context,
                TextField(
                  controller: _weight,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Berat', suffixText: 'gram'),
                ),
                TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Kapasitas (opsional)', suffixText: 'orang'),
                ),
              ),
              const SectionTitle('Stok'),
              if (!_forceSizes)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Punya pilihan ukuran'),
                  subtitle: const Text('Stok dicatat per ukuran, mis. sepatu atau jaket.'),
                  value: _useSizes,
                  onChanged: (v) => setState(() {
                    _useSizes = v;
                    _touched = true;
                    if (v && _sizes.isEmpty) _sizes.add(_SizeRow('', 1));
                  }),
                ),
              if (showSizes) ...[
                for (final (i, row) in _sizes.indexed)
                  Padding(
                    key: ObjectKey(row),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: row.label,
                            onChanged: (_) => _touch(),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Ukuran', isDense: true),
                          ),
                        ),
                        const Spacer(),
                        _Stepper(
                          value: row.stock,
                          onChanged: (v) => setState(() {
                            row.stock = v;
                            _touched = true;
                          }),
                        ),
                        IconButton(
                          tooltip: 'Hapus ukuran',
                          onPressed: _sizes.length > 1
                              ? () => setState(() {
                                    _sizes.removeAt(i).label.dispose();
                                    _touched = true;
                                  })
                              : null,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _sizes.add(_SizeRow(_nextLabel(), 1));
                      _touched = true;
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah ukuran'),
                  ),
                ),
              ] else
                Row(
                  children: [
                    const Expanded(child: Text('Jumlah unit')),
                    _Stepper(
                      value: _stock,
                      min: 1,
                      onChanged: (v) => setState(() {
                        _stock = v;
                        _touched = true;
                      }),
                    ),
                  ],
                ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan di katalog'),
                subtitle: const Text('Matikan bila alat sedang diperbaiki atau tidak disewakan.'),
                value: _active,
                onChanged: (v) => setState(() {
                  _active = v;
                  _touched = true;
                }),
              ),
              if (_errors.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_initial == null ? 'Tambah alat' : 'Simpan perubahan'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Saran label berikutnya: ukuran angka terakhir + 1.
  String _nextLabel() {
    final last = _sizes.isEmpty ? null : int.tryParse(_sizes.last.label.text.trim());
    return last == null ? '' : '${last + 1}';
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged, this.min = 0});

  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Tambah',
            onPressed: value < 99 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      );
}

/// Two fields side by side, stacked when the system font is large so labels are not cut.
Widget _fieldPair(BuildContext context, Widget first, Widget second) {
  if (MediaQuery.textScalerOf(context).scale(1) > 1.15) {
    return Column(children: [first, const SizedBox(height: 12), second]);
  }
  return Row(
    children: [
      Expanded(child: first),
      const SizedBox(width: 12),
      Expanded(child: second),
    ],
  );
}
