import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:xml/xml.dart';

// Load the ORA file
Future<void> readOraFile(final AppModel appModel, String filePath) async {
  try {
    final File oraFile = File(filePath);
    if (!await oraFile.exists()) {
      print('File not found: $filePath');
      return;
    }

    appModel.loadedFileName = filePath;

    // Read the file as bytes
    await readOraFileFromBytes(
      appModel,
      await oraFile.readAsBytes(),
    );
  } catch (e) {
    throw Exception('Failed to read ORA file: $e');
  }
}

// Read the file from  bytes
Future<void> readOraFileFromBytes(
  AppModel appModel,
  Uint8List bytes,
) async {
  // Extract the ZIP contents
  final Archive archive = ZipDecoder().decodeBytes(bytes);

  // Find the stack.xml file
  final ArchiveFile stackFile = archive.files.firstWhere(
    (file) => file.name == 'stack.xml',
    orElse: () => throw Exception('stack.xml not found in ORA file'),
  );

  // Parse the stack.xml content
  final XmlDocument stackXml = XmlDocument.parse(
    String.fromCharCodes(stackFile.content),
  );

  //print(stackXml.toString());
  final XmlElement? rootImage = stackXml.getElement('image');
  appModel.canvasSize = ui.Size(
    double.parse(rootImage!.getAttribute('w')!),
    double.parse(rootImage.getAttribute('h')!),
  );

  // Extract layers
  for (final XmlElement xmlLayer in stackXml.findAllElements('layer')) {
    final String name = xmlLayer.getAttribute('name') ?? 'Unnamed';
    final String opacityAsText = xmlLayer.getAttribute('opacity') ?? '1.0';
    final String visibleAsText = xmlLayer.getAttribute('visible') ?? 'true';

    final PaintLayer newLayer = appModel.addLayerBottom(name);
    newLayer.isVisible = visibleAsText == 'true';
    newLayer.opacity = double.parse(opacityAsText);

    // is there an image on this layer?
    final String? src = xmlLayer.getAttribute('src');
    if (src != null) {
      final String? xAsText = xmlLayer.getAttribute('x');
      final String? yAsText = xmlLayer.getAttribute('y');

      final ui.Offset offset = ui.Offset(
        double.parse(xAsText ?? '0'),
        double.parse(yAsText ?? '0'),
      );

      await addImageToLayer(
        appModel: appModel,
        layer: newLayer,
        archive: archive,
        imageName: src,
        offset: offset,
      );
    }
  }
}

Future<void> addImageToLayer({
  required final AppModel appModel,
  required final PaintLayer layer,
  required final Archive archive,
  required final String imageName,
  required final ui.Offset offset,
}) async {
  try {
    final ArchiveFile file =
        archive.files.firstWhere((f) => f.name == imageName);
    final List<int> bytes = file.content as List<int>;
    final ui.Image image = await decodeImage(bytes);

    layer.addImage(image, offset);
  } catch (e) {
    print(e.toString());
  }
}

Future<ui.Image> decodeImage(List<int> bytes) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(Uint8List.fromList(bytes), completer.complete);
  return completer.future;
}
