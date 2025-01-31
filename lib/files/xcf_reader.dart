// ignore_for_file: avoid_print, constant_identifier_names, always_put_control_body_on_new_line

import 'dart:async';
import 'dart:typed_data';

class FileXcf {
  static const String XCF_SIGNATURE = 'gimp xcf ';

  // Property type constants
  static const int PROP_END = 0;
  static const int PROP_COLORMAP = 1;
  static const int PROP_ACTIVE_LAYER = 2;
  static const int PROP_ACTIVE_CHANNEL = 3;
  static const int PROP_SELECTION = 4;
  static const int PROP_FLOATING_SELECTION = 5;
  static const int PROP_OPACITY = 6;
  static const int PROP_MODE = 7;
  static const int PROP_VISIBLE = 8;
  static const int PROP_LINKED = 9;
  static const int PROP_LOCK_CONTENT = 10;
  static const int PROP_APPLY_MASK = 11;
  static const int PROP_EDIT_MASK = 12;
  static const int PROP_SHOW_MASK = 13;
  static const int PROP_SHOW_MASKED = 14;
  static const int PROP_OFFSETS = 15;
  static const int PROP_COLOR = 16;
  static const int PROP_COMPRESSION = 17;
  static const int PROP_GUIDES = 18;
  static const int PROP_PARASITES = 19;
  static const int PROP_TATTOO = 20;
  static const int PROP_UNIT = 21;
  static const int PROP_PATHS = 22;
  static const int PROP_USER_UNIT = 23;
  static const int PROP_VECTORS = 24;
  static const int PROP_TEXT_LAYER_FLAGS = 25;
  static const int PROP_TEXT_LAYER_HINTS = 26;
  static const int PROP_ITEM_ID = 27;
  static const int PROP_ITEM_LOCKED = 28;
  static const int PROP_GROUP_ITEM_FLAGS = 29;
  static const int PROP_LOCK_POSITION = 30;
  static const int PROP_LOCK_SIZE = 31;
  static const int PROP_LOCK_ALPHA = 32;
  static const int PROP_RESOLUTION = 150;

  int _offset = 0;
  final XcfFile xcfFile = XcfFile();
  late final ByteData _data;
  final Map<String, dynamic> properties = <String, dynamic>{};

  Future<XcfFile> readXcf(Uint8List bytes) async {
    _data = ByteData.sublistView(bytes);

    // Verify XCF signature
    xcfFile.signature = _readString(9);
    if (!xcfFile.signature.startsWith(XCF_SIGNATURE)) {
      throw Exception('Invalid XCF file: incorrect signature');
    }

    // Read version
    xcfFile.version = _readNullTerminatedString();

    // Read basic properties
    xcfFile.width = _readUint32();
    xcfFile.height = _readUint32();
    xcfFile.baseType = _readUint32();

    // Read properties until encountering PROP_END

    while (true) {
      final int propType = _readUint32();
      if (propType == 0) {
        break;
      }

      // PROP_END
      final int propSize = _readUint32();
      final Uint8List propData = _readBytes(propSize);

      // Parse property based on type
      switch (propType) {
        case PROP_COLORMAP:
          properties['colormap'] = _parseColormap(propData);
          break;
        case PROP_COMPRESSION:
          properties['compression'] = propData[0];
          break;
        case PROP_GUIDES:
          properties['guides'] = _parseGuides(propData);
          break;
        case PROP_PARASITES:
          properties['parasites'] = _parseParasites(propSize);
          break;
        case PROP_UNIT:
          // properties['unit'] = _readUint32();
          break;
        case PROP_PATHS:
          // readPropPath();
          break;
        case PROP_RESOLUTION:
          properties['resolution'] = _parseResolution();
          break;

        default:
          print('Unhandled property type: $propType'); // Debug line
          break;
      }
    }

    return xcfFile;
  }

  String _readString(int length) {
    final bytes = _readBytes(length);
    return String.fromCharCodes(bytes);
  }

  Uint8List _readBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _data.getUint8(_offset + i);
    }
    _offset += length;
    return bytes;
  }

  int _readUint32() {
    final value = _data.getUint32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  List<int> _parseColormap(Uint8List data) {
    final colormap = <int>[];
    for (var i = 0; i < data.length; i += 3) {
      final color = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
      colormap.add(color);
    }
    return colormap;
  }

  List<Map<String, int>> _parseGuides(Uint8List data) {
    final guides = <Map<String, int>>[];
    var offset = 0;
    while (offset < data.length) {
      final position = ByteData.view(data.buffer).getInt32(offset, Endian.big);
      final orientation = data[offset + 4];
      guides.add({
        'position': position,
        'orientation': orientation,
      });
      offset += 5;
    }
    return guides;
  }

  double _readFloat() {
    final value = _data.getFloat32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  List<Map<String, dynamic>> _parseParasites(int totalSize) {
    final parasites = <Map<String, dynamic>>[];
    final endOffset = _offset + totalSize;

    print('Parsing parasites at offset $_offset');

    while (_offset < endOffset) {
      // Read parasite name (null-terminated string)
      final name = _readNullTerminatedString();
      if (name.isEmpty) {
        break; // Avoid infinite loops if parsing fails
      }

      print('Found parasite: $name');

      // Read flags (4 bytes)
      if (_offset + 4 > endOffset) break;
      // Safety check
      final int flags = _readUint32();

      // Read size of parasite data
      if (_offset + 4 > endOffset) break; // Safety check
      final int size = _readUint32();

      print('Parasite "$name" size: $size bytes');

      // Read parasite data safely
      if (_offset + size > endOffset) break; // Safety check
      final Uint8List data = _readBytes(size);

      parasites.add({
        'name': name,
        'flags': flags,
        'size': size,
        'data': data,
      });
    }

    return parasites;
  }

  String _readNullTerminatedString() {
    List<int> chars = [];
    final startOffset = _offset; // Track starting position

    while (_offset < _data.lengthInBytes) {
      int byte = _data.getUint8(_offset++);
      if (byte == 0) {
        break; // Stop at null terminator
      }
      chars.add(byte);
    }

    final name = String.fromCharCodes(chars);

    if (name.isEmpty) {
      print('Warning: Exepected a non Empty string at offset $startOffset');
    }

    return name;
  }

  Map<String, double> _parseResolution() {
    // Read the x resolution as float
    final xRes = _readFloat();

    // The next three values are uint32s that we'll skip
    _offset += 12; // Skip 3 uint32s (4 bytes each)

    return {
      'xResolution': xRes,
      'yResolution': xRes, // In XCF, x and y resolution are typically the same
    };
  }

  Future<XcfPath?> readPropPath(propData) async {
    try {
      // Read the length of PROP_PATH data
      int length = _readUint32();
      _offset += length;
      return XcfPath(name: '', strokes: []);

      // int startOffset = _offset; // Store the start position

      // // Read the path name (null-terminated string)
      // String pathName = _readNullTerminatedString();

      // // Read number of strokes
      // int numStrokes = _readUint32();
      // List<Stroke> strokes = [];

      // for (int i = 0; i < numStrokes; i++) {
      //   // Read number of points in this stroke
      //   int numPoints = _readUint32();
      //   List<PathPoint> points = [];

      //   for (int j = 0; j < numPoints; j++) {
      //     // Read 6 double values (48 bytes per point)
      //     double x = _readFloat();
      //     double y = _readFloat();
      //     double c1X = _readFloat();
      //     double c1Y = _readFloat();
      //     double c2X = _readFloat();
      //     double c2Y = _readFloat();

      //     points.add(
      //       PathPoint(
      //         x: x,
      //         y: y,
      //         control1X: c1X,
      //         control1Y: c1Y,
      //         control2X: c2X,
      //         control2Y: c2Y,
      //       ),
      //     );
      //   }

      //   // Read stroke closed flag (1 byte)
      //   bool isClosed = _readBytes(1)[0] == 1;

      //   strokes.add(Stroke(points: points, isClosed: isClosed));
      // }

      // // Validate that we did not exceed the PROP_PATH length
      // int bytesRead = _offset - startOffset;
      // if (bytesRead != length) {
      //   throw Exception('PROP_PATH length mismatch: expected $length bytes, but read $bytesRead bytes.');
      // }

      //return XcfPath(name: pathName, strokes: strokes);
    } catch (e) {
      print('Error reading PROP_PATH: $e');
      return null;
    }
  }
}

class XcfFile {
  String signature = '';
  String version = '';
  int width = 0;
  int height = 0;
  int baseType = 0;
  List<XcfLayer> layers = [];

  String get baseTypeString {
    switch (baseType) {
      case 0:
        return 'RGB';
      case 1:
        return 'GRAY';
      case 2:
        return 'INDEXED';
      default:
        return 'UNKNOWN';
    }
  }

  bool get isNewVersion {
    // Version v004 and later use a different layer structure
    if (version == 'file' ||
        version == 'v001' ||
        version == 'v002' ||
        version == 'v003') {
      return false;
    }
    return true;
  }
}

Future<List<int>> readLayerOffsets(ByteData buffer, int startOffset) async {
  List<int> offsets = [];
  int currentOffset = startOffset;

  while (true) {
    final offset = buffer.getUint32(currentOffset, Endian.big);
    if (offset == 0) {
      break;
    }
    offsets.add(offset);
    currentOffset += 4;
  }

  return offsets;
}

Future<String> readProperty(ByteData buffer, int offset) async {
  final length = buffer.getUint32(offset + 4, Endian.big);
  final bytes = Uint8List.sublistView(buffer, offset + 8, offset + 8 + length);
  return String.fromCharCodes(bytes).replaceAll('\x00', '');
}

Future<XcfLayer> readLayer(
  ByteData buffer,
  int offset,
  bool isNewVersion,
) async {
  final layer = XcfLayer();

  layer.width = buffer.getUint32(offset, Endian.big);
  layer.height = buffer.getUint32(offset + 4, Endian.big);
  layer.type = buffer.getUint32(offset + 8, Endian.big);

  // Skip layer name length (4 bytes)
  final nameLength = buffer.getUint32(offset + 12, Endian.big);
  final nameBytes =
      Uint8List.sublistView(buffer, offset + 16, offset + 16 + nameLength);
  layer.name = String.fromCharCodes(nameBytes).replaceAll('\x00', '');

  // Initialize defaults
  layer.opacity = 255; // Full opacity
  layer.visible = true;

  // Read properties
  int propOffset = offset + 16 + nameLength;
  while (true) {
    final propType = buffer.getUint32(propOffset, Endian.big);
    if (propType == 0) {
      break;
    } // End of properties

    switch (propType) {
      case 6: // Opacity
        layer.opacity = buffer.getUint32(propOffset + 8, Endian.big);
        break;
      case 7: // Visible
        layer.visible = buffer.getUint32(propOffset + 8, Endian.big) != 0;
        break;
    }

    final propLength = buffer.getUint32(propOffset + 4, Endian.big);
    propOffset += 8 + propLength;
  }

  return layer;
}

class XcfPath {
  XcfPath({required this.name, required this.strokes});
  final String name;
  final List<Stroke> strokes;

  @override
  String toString() {
    return 'Path Name: $name, Strokes: ${strokes.length}';
  }
}

class Stroke {
  Stroke({required this.points, required this.isClosed});
  final List<PathPoint> points;
  final bool isClosed;
}

class PathPoint {
  PathPoint({
    required this.x,
    required this.y,
    required this.control1X,
    required this.control1Y,
    required this.control2X,
    required this.control2Y,
  });
  final double x, y;
  final double control1X, control1Y;
  final double control2X, control2Y;

  @override
  String toString() {
    return 'Point(x: $x, y: $y, c1: [$control1X, $control1Y], c2: [$control2X, $control2Y])';
  }
}

class XcfLayer {
  late int width;
  late int height;
  late int type;
  late String name;
  late int opacity;
  late bool visible;

  @override
  String toString() {
    return 'Layer "$name" (${width}x$height), opacity: ${(opacity / 255 * 100).round()}%, ${visible ? "visible" : "hidden"}';
  }
}
