import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive.dart';
import '../../widgets/common.dart';

/// Atribusi foto katalog demo (Wikimedia Commons), wajib untuk lisensi CC BY/BY-SA.
class PhotoCreditsScreen extends StatelessWidget {
  const PhotoCreditsScreen({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await rootBundle.loadString('assets/equipment/credits.json');
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kredit Foto')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _load(),
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(icon: Icons.error_outline, message: 'Gagal memuat kredit: ${snap.error}');
            }
            final items = snap.data;
            if (items == null) return const Center(child: CircularProgressIndicator());
            // Kolom tengah di layar lebar; sisi kosong tetap bisa digulir.
            return LayoutBuilder(builder: (context, c) => ListView.separated(
              padding: centeredPadding(c.maxWidth),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Foto alat pada data demo berasal dari Wikimedia Commons dan dipakai sesuai lisensinya.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }
                final c = items[i - 1];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/equipment/${c['file']}',
                        width: 48, height: 48, fit: BoxFit.cover, cacheWidth: 150),
                  ),
                  title: Text('${c['title']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${c['author']} · ${c['license']}\n${c['source']}',
                      style: const TextStyle(fontSize: 12)),
                  isThreeLine: true,
                );
              },
            ));
          },
        ),
      );
}
