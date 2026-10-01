import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/models.dart';
import 'common.dart';

/// Menampilkan satu [ItemPhoto]. [decodeWidth] (piksel fisik) membatasi
/// ukuran decode agar thumbnail tidak memakan memori sebesar foto aslinya.
class ItemPhotoView extends StatelessWidget {
  const ItemPhotoView(this.photo, {super.key, this.fit = BoxFit.cover, this.decodeWidth});

  final ItemPhoto photo;
  final BoxFit fit;
  final int? decodeWidth;

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext _, Object _, StackTrace? _) => const ColoredBox(
          color: Color(0xFFE8EEEA),
          child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.black38)),
        );
    return switch (photo) {
      AssetPhoto(:final path) => Image.asset(path,
          fit: fit, cacheWidth: decodeWidth, errorBuilder: error, gaplessPlayback: true),
      MemoryPhoto(:final bytes) => Image.memory(bytes,
          fit: fit, cacheWidth: decodeWidth, errorBuilder: error, gaplessPlayback: true),
      NetworkPhoto(:final url) => Image.network(url,
          fit: fit, cacheWidth: decodeWidth, errorBuilder: error, gaplessPlayback: true),
    };
  }
}

/// Thumbnail persegi: foto pertama bila ada, ikon kategori bila tidak.
class ItemThumb extends StatelessWidget {
  const ItemThumb({super.key, required this.photo, required this.categoryId, this.size = 64});

  final ItemPhoto? photo;
  final String categoryId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    if (p == null) return EquipmentThumb(categoryId: categoryId, size: size);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 5),
      child: SizedBox(
        width: size,
        height: size,
        // Mode cover memotong sisi panjang; decode 2x lebar agar foto
        // landscape tetap tajam setelah dipotong jadi persegi.
        child: ItemPhotoView(p, decodeWidth: (size * dpr * 2).round()),
      ),
    );
  }
}

/// Galeri geser di halaman detail alat. Ketuk untuk layar penuh.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.photos, required this.categoryId, this.height = 280});

  final List<ItemPhoto> photos;
  final String categoryId;
  final double height;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return SizedBox(
        height: widget.height * 0.6,
        child: Center(child: EquipmentThumb(categoryId: widget.categoryId, size: 140)),
      );
    }
    final width = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => PhotoViewerScreen(photos: photos, initialIndex: i),
                  ),
                ),
                child: ItemPhotoView(photos[i], decodeWidth: width.round()),
              ),
            ),
            if (photos.length > 1) ...[
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${_page + 1}/${photos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white60,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Foto layar penuh: geser antar foto, cubit untuk zoom.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photos, this.initialIndex = 0});

  final List<ItemPhoto> photos;
  final int initialIndex;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_page + 1} dari ${widget.photos.length}'),
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(child: ItemPhotoView(widget.photos[i], fit: BoxFit.contain)),
          ),
        ),
      );
}

/// Bingkai tambah foto untuk form penyedia.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({super.key, required this.onTap, this.size = 96});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.forest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppColors.forest),
                SizedBox(height: 4),
                Text('Tambah', style: TextStyle(color: AppColors.forest, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}
