
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rentgear/widgets/common.dart';

/// HP tanpa aplikasi kamera: kamera melempar galat, galeri memberi satu foto.
class _NoCameraPicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  final asked = <ImageSource>[];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    asked.add(source);
    if (source == ImageSource.camera) {
      throw PlatformException(code: 'no_available_camera', message: 'No cameras available for taking pictures.');
    }
    return XFile.fromData(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  testWidgets('tanpa aplikasi kamera: ada pesan yang jelas, lalu galeri dibuka', (tester) async {
    final picker = _NoCameraPicker();
    ImagePickerPlatform.instance = picker;
    Uint8List? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await pickPhoto(context),
            child: const Text('Foto'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambil dengan kamera'));
    await tester.pumpAndSettle();

    expect(picker.asked, [ImageSource.camera, ImageSource.gallery]);
    expect(find.text(noCameraMessage), findsOneWidget);
    expect(find.textContaining('PlatformException'), findsNothing);
    expect(picked, [1, 2, 3]);
  });
}
