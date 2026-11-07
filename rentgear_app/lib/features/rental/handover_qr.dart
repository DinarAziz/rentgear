import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/models.dart';

/// QR serah terima di HP penyewa. Toko memindainya saat alat diambil dan saat dikembalikan.
class HandoverQrCard extends StatelessWidget {
  const HandoverQrCard({super.key, required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final pickup = rental.status == RentalStatus.paid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              pickup ? 'Tunjukkan QR ini saat mengambil alat' : 'Tunjukkan QR ini saat mengembalikan alat',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'QR serah terima, kode ${rental.handoverCode}',
              child: QrImageView(
                data: handoverQrPayload(rental),
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              rental.handoverCode!,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bila kamera toko tidak bisa memindai, sebutkan kode di atas. Jangan bagikan kode sebelum Anda berada di toko.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toko memindai QR penyewa atau mengetik kodenya. `null` bila dibatalkan.
Future<String?> askHandoverCode(BuildContext context, Rental rental) {
  final field = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kode serah terima'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pindai QR di HP penyewa, atau ketik enam digit kode yang tampil di bawah QR.'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Pindai QR'),
            onPressed: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => _ScanPage(rentalId: rental.id)),
              );
              if (code != null && context.mounted) Navigator.of(context).pop(code);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: field,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kode 6 digit'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            if (field.text.length == 6) Navigator.of(context).pop(field.text);
          },
          child: const Text('Lanjut'),
        ),
      ],
    ),
  );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage({required this.rentalId});

  final String rentalId;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  String? _warning;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final code = codeFromHandoverQr(raw, widget.rentalId);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
      setState(() => _warning = 'QR ini bukan untuk sewa yang sedang dibuka.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai QR penyewa')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera tidak bisa dibuka. Kembali lalu ketik kode 6 digit dari HP penyewa.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (_warning != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_warning!, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
