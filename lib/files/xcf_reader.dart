// ignore_for_file: avoid_print, constant_identifier_names, always_put_control_body_on_new_line

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fpaint/helpers/list_helper.dart';

/*
The image structure always starts at offset 0 in the XCF file.

  byte[9]     "gimp xcf " File type identification
  byte[4]     version     XCF version
                             "file": version 0
                             "v001": version 1
                             "v002": version 2
                             "v003": version 3
  byte        0            Zero marks the end of the version tag.
  uint32      width        Width of canvas
  uint32      height       Height of canvas
  uint32      base_type    Color mode of the image; one of
                             0: RGB color
                             1: Grayscale
                             2: Indexed color
                           (see enum GimpImageBaseType
                           in libgimpbase/gimpbaseenums.h)
  uint32      precision    Image precision; this field is only present for
                           XCF 4 or over (since GIMP 2.10.0). Its value for
                           XCF 7 or over is one of:
                             100: 8-bit linear integer
                             150: 8-bit gamma integer
                             200: 16-bit linear integer
                             250: 16-bit gamma integer
                             300: 32-bit linear integer
                             350: 32-bit gamma integer
                             500: 16-bit linear floating point
                             550: 16-bit gamma floating point
                             600: 32-bit linear floating point
                             650: 32-bit gamma floating point
                             700: 64-bit linear floating point
                             750: 64-bit gamma floating point
                           For XCF 4 (which was a development version, hence
                           this format should not be found often and may be
                           ignored by readers), its value may be one of:
                             0: 8-bit gamma integer
                             1: 16-bit gamma integer
                             2: 32-bit linear integer
                             3: 16-bit linear floating point
                             4: 32-bit linear floating point
                           For XCF 5 or 6 (which were development versions,
                           hence these formats may be ignored by readers),
                           its value may be one of:
                             100: 8-bit linear integer
                             150: 8-bit gamma integer
                             200: 16-bit linear integer
                             250: 16-bit gamma integer
                             300: 32-bit linear integer
                             350: 32-bit gamma integer
                             400: 16-bit linear floating point
                             450: 16-bit gamma floating point
                             500: 32-bit linear floating point
                             550: 32-bit gamma floating point
                           NOTE: XCF 3 or older's precision was always
                           "8-bit gamma integer".
  property-list        Image properties
  ,-----------------   Repeat once for each layer, topmost layer first:
  | pointer lptr       Pointer to the layer structure.
  `--
  pointer   0           Zero marks the end of the array of layer pointers.
  ,------------------  Repeat once for each channel, in no particular order:
  | pointer cptr       Pointer to the channel structure.
  `--
  pointer   0           Zero marks the end of the array of channel pointers.

The last 4 characters of the initial 13-character identification string are
a version indicator. The version will be higher than 3 if the correct
reconstruction of pixel data from the file requires that the reader
understands features not described in this specification. On the other
hand, optional extra information that can be safely ignored will not
cause the version to increase.

GIMP's XCF writer dynamically selects the lowest version that will
allow the image to be represented. Third-party XCF writers should do
likewise.

Version numbers from v100 upwards have been used by CinePaint, which
originated as a 16-bit fork of GIMP, see "Scope".


*/
enum PropType {
  PROP_END(0),
  PROP_COLORMAP(1),
  PROP_ACTIVE_LAYER(2),
  PROP_ACTIVE_CHANNEL(3),
  PROP_SELECTION(4),
  PROP_FLOATING_SELECTION(5),
  PROP_OPACITY(6),
  PROP_MODE(7),
  PROP_VISIBLE(8),
  PROP_LINKED(9),
  PROP_LOCK_ALPHA(10),
  PROP_APPLY_MASK(11),
  PROP_EDIT_MASK(12),
  PROP_SHOW_MASK(13),
  PROP_SHOW_MASKED(14),
  PROP_OFFSETS(15),
  PROP_COLOR(16),
  PROP_COMPRESSION(17),
  PROP_GUIDES(18),
  PROP_RESOLUTION(19),
  PROP_TATTOO(20),
  PROP_PARASITES(21),
  PROP_UNIT(22),
  PROP_PATHS(23),
  PROP_USER_UNIT(24),
  PROP_VECTORS(25),
  PROP_TEXT_LAYER_FLAGS(26),
  PROP_OLD_SAMPLE_POINTS(27),
  PROP_LOCK_CONTENT(28),
  PROP_GROUP_ITEM(29),
  PROP_ITEM_PATH(30),
  PROP_GROUP_ITEM_FLAGS(31),
  PROP_LOCK_POSITION(32),
  PROP_FLOAT_OPACITY(33),
  PROP_COLOR_TAG(34),
  PROP_COMPOSITE_MODE(35),
  PROP_COMPOSITE_SPACE(36),
  PROP_BLEND_SPACE(37),
  PROP_FLOAT_COLOR(38),
  PROP_SAMPLE_POINTS(39),
  PROP_NUM_PROPS(40);

  const PropType(this.value);
  final int value;
  static PropType? fromValue(int value) {
    return PropType.values.findFirstMatch((e) => e.value == value);
  }
}

class FileXcf {
  static const String XCF_SIGNATURE = 'gimp xcf ';

  int _offset = 0;
  final XcfFile xcfFile = XcfFile();
  late final ByteData _data;
  final Map<String, dynamic> properties = <String, dynamic>{};

  Future<XcfFile> readXcf(Uint8List bytes) async {
    _data = ByteData.sublistView(bytes);

    // Verify XCF signature
    xcfFile.signature = _readString(XCF_SIGNATURE.length);
    if (!xcfFile.signature.startsWith(XCF_SIGNATURE)) {
      throw Exception('Invalid XCF file: incorrect signature');
    }

    // Read version
    xcfFile.version = _readNullTerminatedString();

    // Read basic properties
    xcfFile.width = _readUint32();
    xcfFile.height = _readUint32();
    xcfFile.baseType = _readUint32();
    xcfFile.precision = _readUint32();

    // Read properties until encountering PROP_END
    while (true) {
      final int propTypeValue = _readUint32();
      final PropType? propType = PropType.fromValue(propTypeValue);
      if (propType == null) {
        print('Invalid PropertyTYpe $propTypeValue');
        break;
      }

      print('Property: ${propType.toString()}');
      if (propType == PropType.PROP_END) {
        break;
      }

      switch (propType) {
        case PropType.PROP_COLORMAP:
          /*
            PROP_COLORMAP (essential)
              uint32  1        Type identification
              uint32  3*n+4    Payload length in bytes
              uint32  n        Number of colors in the color map (should be <256)
              ,------------    Repeat n times:
              | byte  r        Red component of a color map color
              | byte  g        Green component of a color map color
              | byte  b        Blue component of a color map color
              `--

              PROP_COLORMAP stores the color map.
              It appears in all indexed images.

              The property will be ignored if it is encountered in an RGB or grayscale
              image. The current GIMP will not write a color map with RGB or
              grayscale images, but some older ones occasionally did, and readers
              should be prepared to gracefully ignore it in those cases.

              Note that in contrast to the palette data model of, for example, the
              PNG format, an XCF color map does not contain alpha components, and
              there is no color map entry for "transparent"; the alpha channel of
              layers that have one is always represented separately.

              The structure here is that of since XCF version 1.  Comments in the
              GIMP source code indicate that XCF version 0 could not store indexed
              images in a sane way; contemporary GIMP versions will complain and
              reinterpret the pixel data as a grayscale image if they meet a
              version-0 indexed image.

              Beware that the payload length of the PROP_COLORMAP in particular
              cannot be trusted: some historic releases of GIMP erroneously
              wrote n+4 instead of 3*n+4 into the length word (but still actually
              followed it by 3*n+4 bytes of payload).          
          */
          final numColors = _readUint32();
          final colorMap = [];

          for (var i = 0; i < numColors; i++) {
            final r = _readBytes(1)[0];
            final g = _readBytes(1)[0];
            final b = _readBytes(1)[0];
            colorMap.add(Color.fromRGBO(r, g, b, 1.0));
          }

          properties['colormap'] = colorMap;
          break;
        case PropType.PROP_COMPRESSION:
          /*
              uint32  17       Type identification
              uint32  1        One byte of payload
              byte    comp     Compression indicator; one of
                        0: No compression
                        1: RLE encoding
                        2: zlib compression
                        3: (Never used, but reserved for some fractal compression)

           */
          properties['compression'] = _readBytes(1)[0];
          // properties['compression'] = _readUint32();
          break;
        case PropType.PROP_GUIDES:
          // properties['guides'] = _parseGuides(propData);
          break;
        case PropType.PROP_PARASITES:
          final int payloadSise = _readUint32();
          properties['parasites'] = _parseParasites(payloadSise);
          break;
        case PropType.PROP_UNIT:
          // properties['unit'] = _readUint32();
          break;
        case PropType.PROP_PATHS:
          // readPropPath();
          break;
        case PropType.PROP_RESOLUTION:
          // properties['resolution'] = _parseResolution();
          break;
        case PropType.PROP_TATTOO:
          // properties['resolution'] = _parseResolution();
          break;

        default:
          print(
            'Unhandled property type: ${propType.toString()}',
          ); // Debug line
          break;
      }
    }

    // Read layer pointers
    List<int> layerPointers = [];
    while (true) {
      final pointer = _readUint32();
      if (pointer == 0) break;
      layerPointers.add(pointer);
    }

    // Read layers
    for (final pointer in layerPointers) {
      final savedOffset = _offset;
      _offset = pointer;
      final layer = await _readLayer(_data, _offset);
      xcfFile.layers.add(layer);
      _offset = savedOffset;
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

  // ignore: unused_element
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
  int precision = 0;
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

Future<String> readProperty(ByteData buffer, int offset) async {
  final length = buffer.getUint32(offset + 4, Endian.big);
  final bytes = Uint8List.sublistView(buffer, offset + 8, offset + 8 + length);
  return String.fromCharCodes(bytes).replaceAll('\x00', '');
}

Future<XcfLayer> _readLayer(
  ByteData buffer,
  int offset,
) async {
  final XcfLayer layer = XcfLayer(
    width: buffer.getUint32(offset, Endian.big),
    height: buffer.getUint32(offset + 4, Endian.big),
    layerType: buffer.getUint32(offset + 8, Endian.big),
  );

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
        layer.opacity = buffer.getUint32(propOffset + 8, Endian.big).toDouble();
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
  XcfLayer({
    this.name = '',
    this.width = 0,
    this.height = 0,
    this.layerType = 0,
    this.properties = const {},
    this.hierarchy,
  });
  String name;
  final int width;
  final int height;
  final int layerType;
  final Map<String, dynamic> properties;
  final XcfHierarchy? hierarchy;
  double opacity = 0;
  bool visible = false;

  @override
  String toString() {
    return 'Layer(name: $name, size: ${width}x$height, type: $layerType, properties: $properties)';
  }
}

class XcfHierarchy {
  XcfHierarchy({
    required this.width,
    required this.height,
    required this.bpp,
    required this.tileOffsets,
  });
  final int width;
  final int height;
  final int bpp;
  final List<int> tileOffsets;

  @override
  String toString() {
    return 'Hierarchy(width: $width, height: $height, bpp: $bpp, tileOffsets: $tileOffsets)';
  }
}

enum GimpImageBaseType { GIMP_RGB, GIMP_GRAY, GIMP_INDEXED }

enum GimpLayerMode {
  GIMP_LAYER_MODE_NORMAL_LEGACY,
  GIMP_LAYER_MODE_DISSOLVE,
  GIMP_LAYER_MODE_BEHIND_LEGACY,
  GIMP_LAYER_MODE_MULTIPLY_LEGACY,
  GIMP_LAYER_MODE_SCREEN_LEGACY,
  GIMP_LAYER_MODE_OVERLAY_LEGACY,
  GIMP_LAYER_MODE_DIFFERENCE_LEGACY,
  GIMP_LAYER_MODE_ADDITION_LEGACY,
  GIMP_LAYER_MODE_SUBTRACT_LEGACY,
  GIMP_LAYER_MODE_DARKEN_ONLY_LEGACY,
  GIMP_LAYER_MODE_LIGHTEN_ONLY_LEGACY,
  GIMP_LAYER_MODE_HSV_HUE_LEGACY,
  GIMP_LAYER_MODE_HSV_SATURATION_LEGACY,
  GIMP_LAYER_MODE_HSL_COLOR_LEGACY,
  GIMP_LAYER_MODE_HSV_VALUE_LEGACY,
  GIMP_LAYER_MODE_DIVIDE_LEGACY,
  GIMP_LAYER_MODE_DODGE_LEGACY,
  GIMP_LAYER_MODE_BURN_LEGACY,
  GIMP_LAYER_MODE_HARDLIGHT_LEGACY,
  GIMP_LAYER_MODE_SOFTLIGHT_LEGACY,
  GIMP_LAYER_MODE_GRAIN_EXTRACT_LEGACY,
  GIMP_LAYER_MODE_GRAIN_MERGE_LEGACY,
  GIMP_LAYER_MODE_COLOR_ERASE_LEGACY,
  GIMP_LAYER_MODE_OVERLAY,
  GIMP_LAYER_MODE_LCH_HUE,
  GIMP_LAYER_MODE_LCH_CHROMA,
  GIMP_LAYER_MODE_LCH_COLOR,
  GIMP_LAYER_MODE_LCH_LIGHTNESS,
  GIMP_LAYER_MODE_NORMAL,
  GIMP_LAYER_MODE_BEHIND,
  GIMP_LAYER_MODE_MULTIPLY,
  GIMP_LAYER_MODE_SCREEN,
  GIMP_LAYER_MODE_DIFFERENCE,
  GIMP_LAYER_MODE_ADDITION,
  GIMP_LAYER_MODE_SUBTRACT,
  GIMP_LAYER_MODE_DARKEN_ONLY,
  GIMP_LAYER_MODE_LIGHTEN_ONLY,
  GIMP_LAYER_MODE_HSV_HUE,
  GIMP_LAYER_MODE_HSV_SATURATION,
  GIMP_LAYER_MODE_HSL_COLOR,
  GIMP_LAYER_MODE_HSV_VALUE,
  GIMP_LAYER_MODE_DIVIDE,
  GIMP_LAYER_MODE_DODGE,
  GIMP_LAYER_MODE_BURN,
  GIMP_LAYER_MODE_HARDLIGHT,
  GIMP_LAYER_MODE_SOFTLIGHT,
  GIMP_LAYER_MODE_GRAIN_EXTRACT,
  GIMP_LAYER_MODE_GRAIN_MERGE,
  GIMP_LAYER_MODE_VIVID_LIGHT,
  GIMP_LAYER_MODE_PIN_LIGHT,
  GIMP_LAYER_MODE_LINEAR_LIGHT,
  GIMP_LAYER_MODE_HARD_MIX,
  GIMP_LAYER_MODE_EXCLUSION,
  GIMP_LAYER_MODE_LINEAR_BURN,
  GIMP_LAYER_MODE_LUMA_DARKEN_ONLY,
  GIMP_LAYER_MODE_LUMA_LIGHTEN_ONLY,
  GIMP_LAYER_MODE_LUMINANCE,
  GIMP_LAYER_MODE_COLOR_ERASE,
  GIMP_LAYER_MODE_ERASE,
  GIMP_LAYER_MODE_MERGE,
  GIMP_LAYER_MODE_SPLIT,
  GIMP_LAYER_MODE_PASS_THROUGH,
}
