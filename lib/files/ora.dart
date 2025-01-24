import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:xml/xml.dart';

// Load the ORA file
Future<void> readOraFile(final AppModel appModel, String filePath) async {
  try {
    final oraFile = File(filePath);
    if (!await oraFile.exists()) {
      print('File not found: $filePath');
      return;
    }

    appModel.loadedFileName = filePath;

    // Read the file as bytes
    final Uint8List bytes = await oraFile.readAsBytes();

    // Extract the ZIP contents
    final Archive archive = ZipDecoder().decodeBytes(bytes);

    for (final ArchiveFile file in archive.files) {
      print('- ${file.name}');
    }

    // Find the stack.xml file
    final stackFile = archive.files.firstWhere(
      (file) => file.name == 'stack.xml',
      orElse: () => throw Exception('stack.xml not found in ORA file'),
    );

    // Parse the stack.xml content
    final XmlDocument stackXml =
        XmlDocument.parse(String.fromCharCodes(stackFile.content));

    // Extract layers
    for (final XmlElement xmlLayer in stackXml.findAllElements('layer')) {
      final String name = xmlLayer.getAttribute('name') ?? 'Unnamed';
      final String opacityAsText = xmlLayer.getAttribute('opacity') ?? '1.0';
      final String visibleAsText = xmlLayer.getAttribute('visible') ?? 'true';

      final PaintLayer newLayer = appModel.addLayerBottom(name);
      newLayer.isVisible = visibleAsText == 'true';
      newLayer.opacity = double.parse(opacityAsText);
    }

    // Extract PNG image data for layers (if needed)
    for (final ArchiveFile file
        in archive.files.where((file) => file.name.endsWith('.png'))) {
      final String outputPath = 'output/${file.name}';
      final File outputFile = File(outputPath)..createSync(recursive: true);
      outputFile.writeAsBytesSync(file.content);
      // print('Extracted image: $outputPath');
    }
  } catch (e) {
    throw Exception('Failed to read ORA file: $e');
  }
}
