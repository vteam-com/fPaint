import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/providers/layers_provider.dart';

void main() {
  test('resolveRecentFileThumbnailBytes leaves non-ORA bytes unchanged', () async {
    final Uint8List pngBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final Uint8List? resolvedBytes = await resolveRecentFileThumbnailBytes(
      fileBytes: pngBytes,
      path: '/tmp/sample.png',
    );

    expect(resolvedBytes, same(pngBytes));
  });

  test('resolveRecentFileThumbnailBytes extracts ORA preview bytes', () async {
    final LayersProvider layers = LayersProvider()..size = const ui.Size(8, 4);
    final Uint8List archiveBytes = Uint8List.fromList(await createOraArchive(layers));

    final Uint8List? resolvedBytes = await resolveRecentFileThumbnailBytes(
      fileBytes: archiveBytes,
      path: '/tmp/sample.ORA',
    );

    expect(resolvedBytes, isNotNull);

    final ui.Image previewImage = await decodeImage(resolvedBytes!);
    expect(previewImage.width, AppLayout.thumbnailMaxHeight.toInt() * 2);
    expect(previewImage.height, AppLayout.thumbnailMaxHeight.toInt());
  });
}
