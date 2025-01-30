// ignore_for_file: avoid_print, constant_identifier_names

import 'dart:async';
import 'dart:typed_data';

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

class XcfHeader {
  late String magic;
  late String version;
  late int width;
  late int height;
  late int baseType;
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

  String get versionInfo {
    switch (version) {
      case 'file':
        return 'v001 (File)';
      case 'v001':
        return 'v001';
      case 'v002':
        return 'v002';
      case 'v003':
        return 'v003';
      case 'v004':
        return 'v004';
      case 'v005':
        return 'v005';
      case 'v006':
        return 'v006';
      case 'v007':
        return 'v007';
      case 'v008':
        return 'v008';
      case 'v009':
        return 'v009';
      case 'v010':
        return 'v010';
      case 'v011':
        return 'v011 (Latest)';
      default:
        return 'Unknown version: $version';
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

class FileXcf {
  static const String XCF_SIGNATURE = 'gimp xcf ';

  // Property type constants
  static const int PROP_END = 0;
  static const int PROP_COLORMAP = 1;
  static const int PROP_COMPRESSION = 2;
  static const int PROP_GUIDES = 3;
  static const int PROP_PARASITES = 22;
  static const int PROP_RESOLUTION = 150;

  int _offset = 0;
  final header = XcfHeader();
  late final ByteData _data;

  Future<XcfHeader> readXcf(Uint8List bytes) async {
    _data = ByteData.sublistView(bytes);

    // Verify XCF signature
    final signature = _readString(9);
    if (!signature.startsWith(XCF_SIGNATURE)) {
      throw Exception('Invalid XCF file: incorrect signature');
    }

    // Read version
    header.version = _readString(5);

    // Read basic properties
    header.width = _readUint32();
    header.height = _readUint32();
    header.baseType = _readUint32();

    // Read properties until encountering PROP_END
    final properties = <String, dynamic>{};
    while (true) {
      final propType = _readUint32();
      if (propType == 0) {
        break;
      }

      // PROP_END
      final propSize = _readUint32();
      final propData = _readBytes(propSize);

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
        case PROP_RESOLUTION:
          properties['resolution'] = _parseResolution();
          break;

        default:
          print('Unhandled property type: $propType'); // Debug line
          break;
      }
    }

    return header;
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

    print('Starting to parse parasites at offset $_offset');

    while (_offset < endOffset) {
      // Read parasite name (null-terminated string)
      final name = _readNullTerminatedString();
      print('Found parasite: $name');

      // Read flags (4 bytes)
      final flags = _readUint32();

      // Read size of parasite data
      final size = _readUint32();
      print('Parasite $name size: $size bytes');

      // Read parasite data
      final data = _readBytes(size);

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
    while (true) {
      int byte = _data.getUint8(_offset++);
      if (byte == 0) {
        break;
      }
      chars.add(byte);
    }
    return String.fromCharCodes(chars);
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
}
