import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

Widget textAction(final String fileName) {
  String action = kIsWeb ? 'Download' : 'Save';
  String text = '$action as "$fileName"';

  return Text(text);
}

void sharePanel(final BuildContext context) {
  final LayersProvider layers = LayersProvider.of(context);
  showModalBottomSheet(
    context: context,
    builder: (final BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy to clipboard'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportToClipboard(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: textAction('image.PNG'),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsPng(layers);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: textAction('image.JPG'),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsJpeg(layers);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: textAction('image.ORA'),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsOra(layers);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _onExportToClipboard(final BuildContext context) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard != null) {
    final Uint8List image =
        await capturePainterToImageBytes(LayersProvider.of(context));
    final DataWriterItem item = DataWriterItem(suggestedName: 'fPaint.png');
    item.add(Formats.png(image));
    await clipboard.write([item]);
  } else {
    //
  }
}

Future<Uint8List> capturePainterToImageBytes(
  final LayersProvider layers,
) async {
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Draw the custom painter on the canvas
  final CanvasPanelPainter painter = CanvasPanelPainter(layers);

  painter.paint(canvas, layers.size);

  // End the recording and get the picture
  final Picture picture = recorder.endRecording();

  // Convert the picture to an image
  final ui.Image image = await picture.toImage(
    layers.size.width.toInt(),
    layers.size.height.toInt(),
  );

  // Convert the image to byte data (e.g., PNG)
  final ByteData? byteData = await image.toByteData(
    format: ImageByteFormat.png,
  );
  return byteData!.buffer.asUint8List();
}
