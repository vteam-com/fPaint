import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/canvas.dart';
import 'package:fpaint/files/ora.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

void share(final BuildContext context) {
  final AppModel appModel = Provider.of<AppModel>(context, listen: false);

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
                leading: Icon(Icons.copy),
                title: Text('Copy to clipboard'),
                onTap: () {
                  Navigator.pop(context);
                  _onExportToClipboard(context);
                },
              ),
              if (kIsWeb)
                ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Download'),
                  onTap: () {
                    Navigator.pop(context);
                    _onExportToDownload(context);
                  },
                ),
              if (!kIsWeb)
                ListTile(
                  leading: Icon(Icons.save),
                  title: Text('Save to file'),
                  onTap: () async {
                    final String? filePath = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save image',
                      fileName: 'image.ora',
                      allowedExtensions: ['ora'],
                      type: FileType.custom,
                    );
                    if (filePath != null) {
                      await saveToORA(appModel: appModel, filePath: filePath);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
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
    final Uint8List image = await _capturePainterToImageBytes(context);
    final DataWriterItem item = DataWriterItem(suggestedName: 'fPaint.png');
    item.add(Formats.png(image));
    await clipboard.write([item]);
  } else {
    //
  }
}

void _onExportToDownload(final BuildContext context) async {
  // final Uint8List image = await _capturePainterToImageBytes(context);
  // final DataWriterItem item = DataWriterItem(suggestedName: 'fPaint.png');
  // TODO
}

Future<Uint8List> _capturePainterToImageBytes(BuildContext context) async {
  final AppModel model = Provider.of<AppModel>(context, listen: false);
  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  // Draw the custom painter on the canvas
  final MyCanvasPainter painter = MyCanvasPainter(model);

  painter.paint(canvas, model.canvasSize);

  // End the recording and get the picture
  final Picture picture = recorder.endRecording();

  // Convert the picture to an image
  final image = await picture.toImage(
    model.canvasSize.width.toInt(),
    model.canvasSize.height.toInt(),
  );

  // Convert the image to byte data (e.g., PNG)
  final ByteData? byteData = await image.toByteData(
    format: ImageByteFormat.png,
  );
  return byteData!.buffer.asUint8List();
}
