import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// PSD `lsct` section types used by the fixture builder.
enum PsdSectionType {
  /// A regular, pixel-bearing layer (no `lsct` block is written).
  normal(-1),

  /// An expanded group folder.
  openFolder(1),

  /// A collapsed group folder.
  closedFolder(2),

  /// The hidden divider that closes a group.
  boundingSectionDivider(3);

  const PsdSectionType(this.value);

  final int value;
}

/// An opaque RGB fill colour for a fixture layer.
class TestPsdColor {
  const TestPsdColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

/// One layer to write into a fixture PSD.
class TestPsdLayer {
  const TestPsdLayer({
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.color,
    this.opacity = 255,
    this.blendMode = img.PsdBlendMode.normal,
    this.visible = true,
    this.sectionType = PsdSectionType.normal,
  });

  final String name;
  final int left;
  final int top;
  final int width;
  final int height;
  final TestPsdColor color;

  /// PSD opacity, 0-255.
  final int opacity;

  /// PSD blend-mode four-character code, as an int.
  final int blendMode;

  final bool visible;

  /// Whether this record is a pixel layer or a group folder/divider.
  final PsdSectionType sectionType;
}

const int _psdSignature = 0x38425053; // '8BPS'
const int _psdResourceSignature = 0x3842494d; // '8BIM'
const int _psdVersion = 1;
const int _psdChannelCount = 3;
const int _psdDepth = 8;
const int _psdColorModeRgb = 3;
const int _psdCompressionNone = 0;
const int _psdHiddenFlag = 2;
const String _psdSectionDividerTag = 'lsct';

/// Builds a minimal but standards-conformant RGB/8-bit PSD document.
///
/// Photoshop files are large and opaque, so tests that need a specific layer
/// arrangement (groups, blend modes, hidden layers) synthesize one here instead
/// of committing a binary per case. Channels are written uncompressed, which
/// the PSD spec allows and the decoder reads.
///
/// [layers] are listed bottom-to-top, matching PSD storage order. An empty list
/// produces a flattened PSD with no layer records.
Uint8List buildTestPsd({
  required int width,
  required int height,
  required List<TestPsdLayer> layers,
}) {
  final _ByteWriter out = _ByteWriter();

  // ---- File header ----
  out
    ..uint32(_psdSignature)
    ..uint16(_psdVersion)
    ..bytes(Uint8List(6)) // reserved
    ..uint16(_psdChannelCount)
    ..uint32(height)
    ..uint32(width)
    ..uint16(_psdDepth)
    ..uint16(_psdColorModeRgb)
    // ---- Color mode data (empty for RGB) ----
    ..uint32(0)
    // ---- Image resources (none) ----
    ..uint32(0);

  // ---- Layer and mask information ----
  final Uint8List layerAndMask = _buildLayerAndMaskSection(layers);
  out
    ..uint32(layerAndMask.length)
    ..bytes(layerAndMask);

  // ---- Merged image data: one uncompressed plane per channel ----
  out.uint16(_psdCompressionNone);
  for (int channel = 0; channel < _psdChannelCount; channel++) {
    out.bytes(Uint8List(width * height));
  }

  return out.takeBytes();
}

/// Builds the layer-and-mask section: layer info, then an empty global mask.
Uint8List _buildLayerAndMaskSection(List<TestPsdLayer> layers) {
  final _ByteWriter out = _ByteWriter();

  if (layers.isEmpty) {
    // A flattened PSD still carries the section, with a zero-length layer info
    // block and a zero-length global mask block.
    out
      ..uint32(0)
      ..uint32(0);
    return out.takeBytes();
  }

  final Uint8List layerInfo = _buildLayerInfo(layers);
  out
    ..uint32(layerInfo.length)
    ..bytes(layerInfo)
    ..uint32(0); // global layer mask info

  return out.takeBytes();
}

/// Builds the layer info block: the record table followed by channel pixels.
Uint8List _buildLayerInfo(List<TestPsdLayer> layers) {
  final _ByteWriter out = _ByteWriter();
  out.int16(layers.length);

  for (final TestPsdLayer layer in layers) {
    out.bytes(_buildLayerRecord(layer));
  }

  for (final TestPsdLayer layer in layers) {
    out.bytes(_buildLayerChannelData(layer));
  }

  final Uint8List info = out.takeBytes();
  // The layer info block is padded to an even length.
  if (info.length.isOdd) {
    final _ByteWriter padded = _ByteWriter()
      ..bytes(info)
      ..byte(0);
    return padded.takeBytes();
  }
  return info;
}

/// Builds one layer record: bounds, channel table, blending info and extras.
Uint8List _buildLayerRecord(TestPsdLayer layer) {
  final _ByteWriter out = _ByteWriter();
  final int right = layer.left + layer.width;
  final int bottom = layer.top + layer.height;
  final int planeLength = layer.width * layer.height;
  // Each channel plane is prefixed by its own 2-byte compression marker.
  final int channelLength = planeLength + 2;

  out
    ..uint32(layer.top)
    ..uint32(layer.left)
    ..uint32(bottom)
    ..uint32(right)
    ..uint16(_psdChannelCount);

  for (int channelId = 0; channelId < _psdChannelCount; channelId++) {
    out
      ..int16(channelId)
      ..uint32(channelLength);
  }

  out
    ..uint32(_psdResourceSignature)
    ..uint32(layer.blendMode)
    ..byte(layer.opacity)
    ..byte(0) // clipping
    ..byte(layer.visible ? 0 : _psdHiddenFlag)
    ..byte(0); // filler

  final Uint8List extra = _buildLayerExtraData(layer);
  out
    ..uint32(extra.length)
    ..bytes(extra);

  return out.takeBytes();
}

/// Builds a layer's extra data: mask, blending ranges, name and `lsct` block.
Uint8List _buildLayerExtraData(TestPsdLayer layer) {
  final _ByteWriter out = _ByteWriter()
    ..uint32(0) // layer mask data
    ..uint32(0); // layer blending ranges

  // Pascal-style name, padded to a multiple of 4 bytes including the length
  // byte itself.
  final List<int> nameBytes = layer.name.codeUnits;
  out
    ..byte(nameBytes.length)
    ..bytes(Uint8List.fromList(nameBytes));
  final int namePadding = (4 - (nameBytes.length % 4)) - 1;
  if (namePadding > 0) {
    out.bytes(Uint8List(namePadding));
  }

  if (layer.sectionType != PsdSectionType.normal) {
    out
      ..uint32(_psdResourceSignature)
      ..ascii(_psdSectionDividerTag)
      ..uint32(4)
      ..uint32(layer.sectionType.value);
  }

  return out.takeBytes();
}

/// Builds a layer's channel planes, each uncompressed and flat-filled.
Uint8List _buildLayerChannelData(TestPsdLayer layer) {
  final _ByteWriter out = _ByteWriter();
  final int planeLength = layer.width * layer.height;
  final List<int> channelValues = <int>[layer.color.r, layer.color.g, layer.color.b];

  for (final int value in channelValues) {
    out
      ..uint16(_psdCompressionNone)
      ..bytes(Uint8List(planeLength)..fillRange(0, planeLength, value));
  }

  return out.takeBytes();
}

/// Big-endian byte writer, matching PSD's byte order.
class _ByteWriter {
  final BytesBuilder _builder = BytesBuilder();

  void byte(int value) => _builder.addByte(value);

  void uint16(int value) => _builder.add(<int>[(value >> 8) & 0xff, value & 0xff]);

  void int16(int value) => uint16(value & 0xffff);

  void uint32(int value) => _builder.add(<int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ]);

  void ascii(String value) => _builder.add(value.codeUnits);

  void bytes(Uint8List value) => _builder.add(value);

  Uint8List takeBytes() => _builder.takeBytes();
}
