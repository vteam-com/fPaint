part of 'file_tiff.dart';

/// Writes a classic TIFF with one flattened root image and one SubIFD per source layer.
Uint8List _encodeLayeredTiff({
  required final img.Image compositeImage,
  required final List<_LayerFrame> layerFrames,
}) {
  final _TiffDirectoryLayout rootLayout = _buildRootDirectoryLayout(
    compositeImage: compositeImage,
    layerCount: layerFrames.length,
  );
  final List<_TiffDirectoryLayout> layerLayouts = layerFrames.map(_buildLayerDirectoryLayout).toList(growable: false);

  int nextOffset = TiffConstants.headerSize;
  rootLayout.startOffset = nextOffset;
  nextOffset += rootLayout.totalByteSize;

  for (final _TiffDirectoryLayout layerLayout in layerLayouts) {
    layerLayout.startOffset = nextOffset;
    nextOffset += layerLayout.totalByteSize;
  }

  rootLayout.assignBlockOffsets();
  for (final _TiffDirectoryLayout layerLayout in layerLayouts) {
    layerLayout.assignBlockOffsets();
  }

  rootLayout.populateSubIfdOffsets(
    layerLayouts.map((final _TiffDirectoryLayout layout) => layout.startOffset).toList(growable: false),
  );

  final ByteData byteData = ByteData(nextOffset);
  final Uint8List bytes = byteData.buffer.asUint8List();
  int offset = TiffConstants.noValue;

  byteData.setUint8(offset++, TiffConstants.byteOrderLE1);
  byteData.setUint8(offset++, TiffConstants.byteOrderLE2);
  byteData.setUint16(offset, TiffConstants.magic, Endian.little);
  offset += AppMath.pair;
  byteData.setUint32(offset, TiffConstants.headerSize, Endian.little);

  _writeDirectoryLayout(byteData, bytes, rootLayout);
  for (final _TiffDirectoryLayout layerLayout in layerLayouts) {
    _writeDirectoryLayout(byteData, bytes, layerLayout);
  }

  return bytes;
}

/// Builds the root TIFF directory that stores the flattened composite image.
_TiffDirectoryLayout _buildRootDirectoryLayout({
  required final img.Image compositeImage,
  required final int layerCount,
}) {
  final List<_TiffTagEntry> entries = <_TiffTagEntry>[];
  final List<_TiffDataBlock> blocks = <_TiffDataBlock>[];

  final _TiffDataBlock pixelBlock = _pixelBlock(
    compositeImage,
    writeBottomUp: false,
  );
  final _TiffDataBlock subIfdBlock = _longArrayBlock(
    List<int>.filled(layerCount, TiffConstants.noValue, growable: false),
  );

  entries.add(_longValueEntry(TiffConstants.tagImageWidth, compositeImage.width));
  entries.add(_longValueEntry(TiffConstants.tagImageHeight, compositeImage.height));
  entries.add(_shortArrayEntry(TiffConstants.tagBitsPerSample, _rgbaBitsPerSampleValues(), blocks));
  entries.add(_shortValueEntry(TiffConstants.tagCompression, TiffConstants.compressionNone));
  entries.add(_shortValueEntry(TiffConstants.tagPhotometricInterpretation, TiffConstants.photometricRgb));
  entries.add(_shortValueEntry(TiffConstants.tagFillOrder, TiffConstants.fillOrderMsbToLsb));
  entries.add(_offsetBlockEntry(TiffConstants.tagStripOffsets, TiffConstants.typeLong, 1, pixelBlock));
  entries.add(_shortValueEntry(TiffConstants.tagOrientation, TiffConstants.orientationTopLeft));
  entries.add(_shortValueEntry(TiffConstants.tagSamplesPerPixel, TiffConstants.rgbaChannelCount));
  entries.add(_longValueEntry(TiffConstants.tagRowsPerStrip, compositeImage.height));
  entries.add(_longValueEntry(TiffConstants.tagStripByteCounts, pixelBlock.bytes.length));
  entries.add(
    _rationalEntry(TiffConstants.tagXResolution, TiffConstants.defaultDpi, TiffConstants.dpiDenominator, blocks),
  );
  entries.add(
    _rationalEntry(TiffConstants.tagYResolution, TiffConstants.defaultDpi, TiffConstants.dpiDenominator, blocks),
  );
  entries.add(_shortValueEntry(TiffConstants.tagPlanarConfiguration, TiffConstants.planarChunky));
  entries.add(_rationalEntry(TiffConstants.tagXPosition, TiffConstants.noValue, TiffConstants.dpiDenominator, blocks));
  entries.add(_rationalEntry(TiffConstants.tagYPosition, TiffConstants.noValue, TiffConstants.dpiDenominator, blocks));
  entries.add(_shortValueEntry(TiffConstants.tagResolutionUnit, TiffConstants.resolutionUnitInch));
  entries.add(_pageNumberEntry(TiffConstants.noValue, TiffConstants.noValue));
  entries.add(_asciiEntry(TiffConstants.tagSoftware, TiffConstants.sketchBookSoftware, blocks));
  entries.add(_asciiEntry(TiffConstants.tagHostComputer, TiffConstants.sketchBookRootModelPayload, blocks));

  final _TiffTagEntry subIfdEntry = _offsetBlockEntry(
    TiffConstants.tagSubIfd,
    TiffConstants.typeLong,
    layerCount,
    subIfdBlock,
  );
  entries.add(subIfdEntry);

  entries.add(_shortValueEntry(TiffConstants.tagExtraSamples, TiffConstants.extraSamplesAssociatedAlpha));
  entries.add(_shortArrayEntry(TiffConstants.tagSampleFormat, _rgbaSampleFormatValues(), blocks));
  entries.add(_asciiEntry(TiffConstants.tagSketchBookLayerModel, TiffConstants.sketchBookRootModelPayload, blocks));
  entries.add(_asciiEntry(TiffConstants.tagSketchBookVersion, TiffConstants.sketchBookVersion, blocks));

  blocks.add(subIfdBlock);
  blocks.add(pixelBlock);

  return _TiffDirectoryLayout(
    entries: entries,
    blocks: blocks,
    subIfdEntry: subIfdEntry,
    subIfdBlock: subIfdBlock,
  );
}

/// Builds a TIFF directory for one cropped layer page.
_TiffDirectoryLayout _buildLayerDirectoryLayout(final _LayerFrame frame) {
  final List<_TiffTagEntry> entries = <_TiffTagEntry>[];
  final List<_TiffDataBlock> blocks = <_TiffDataBlock>[];
  final _TiffDataBlock pixelBlock = _pixelBlock(
    frame.image,
    writeBottomUp: true,
  );

  entries.add(_longValueEntry(TiffConstants.tagImageWidth, frame.image.width));
  entries.add(_longValueEntry(TiffConstants.tagImageHeight, frame.image.height));
  entries.add(_shortArrayEntry(TiffConstants.tagBitsPerSample, _rgbaBitsPerSampleValues(), blocks));
  entries.add(_shortValueEntry(TiffConstants.tagCompression, TiffConstants.compressionNone));
  entries.add(_shortValueEntry(TiffConstants.tagPhotometricInterpretation, TiffConstants.photometricRgb));
  entries.add(_shortValueEntry(TiffConstants.tagFillOrder, TiffConstants.fillOrderMsbToLsb));
  entries.add(_asciiEntry(TiffConstants.tagImageDescription, frame.description, blocks));
  entries.add(_asciiEntry(TiffConstants.tagModel, TiffConstants.sketchBookLayerModelPayload, blocks));
  entries.add(_offsetBlockEntry(TiffConstants.tagStripOffsets, TiffConstants.typeLong, 1, pixelBlock));
  entries.add(_shortValueEntry(TiffConstants.tagOrientation, TiffConstants.orientationBottomLeft));
  entries.add(_shortValueEntry(TiffConstants.tagSamplesPerPixel, TiffConstants.rgbaChannelCount));
  entries.add(_longValueEntry(TiffConstants.tagRowsPerStrip, frame.image.height));
  entries.add(_longValueEntry(TiffConstants.tagStripByteCounts, pixelBlock.bytes.length));
  entries.add(_shortValueEntry(TiffConstants.tagPlanarConfiguration, TiffConstants.planarChunky));
  entries.add(_asciiEntry(TiffConstants.tagPageName, frame.layerName, blocks));
  entries.add(
    _rationalEntry(
      TiffConstants.tagXPosition,
      _encodeSketchBookPosition(frame.offset.dx),
      TiffConstants.sketchBookPositionDenominator,
      blocks,
    ),
  );
  entries.add(
    _rationalEntry(
      TiffConstants.tagYPosition,
      _encodeSketchBookPosition(frame.offset.dy),
      TiffConstants.sketchBookPositionDenominator,
      blocks,
    ),
  );
  entries.add(_shortValueEntry(TiffConstants.tagExtraSamples, TiffConstants.extraSamplesAssociatedAlpha));
  entries.add(_shortArrayEntry(TiffConstants.tagSampleFormat, _rgbaSampleFormatValues(), blocks));
  entries.add(_asciiEntry(TiffConstants.tagSketchBookLayerModel, TiffConstants.sketchBookLayerModelPayload, blocks));
  entries.add(_asciiEntry(TiffConstants.tagSketchBookLayerFlags, TiffConstants.sketchBookLayerFlagsPayload, blocks));
  entries.add(_shortTextEntry(TiffConstants.tagSketchBookLayerName, frame.layerName, blocks));

  blocks.add(pixelBlock);

  return _TiffDirectoryLayout(
    entries: entries,
    blocks: blocks,
  );
}

/// Writes one TIFF directory and all of its data blocks into the output buffer.
void _writeDirectoryLayout(
  final ByteData byteData,
  final Uint8List bytes,
  final _TiffDirectoryLayout layout,
) {
  int offset = layout.startOffset;

  byteData.setUint16(offset, layout.entries.length, Endian.little);
  offset += AppMath.pair;

  for (final _TiffTagEntry entry in layout.entries) {
    byteData.setUint16(offset, entry.tag, Endian.little);
    offset += AppMath.pair;
    byteData.setUint16(offset, entry.type, Endian.little);
    offset += AppMath.pair;
    byteData.setUint32(offset, entry.count, Endian.little);
    offset += AppMath.bytesPerPixel;

    if (entry.inlineBytes != null) {
      for (int i = 0; i < entry.inlineBytes!.length && i < AppMath.bytesPerPixel; i++) {
        bytes[offset + i] = entry.inlineBytes![i];
      }
    } else if (entry.inlineValue != null) {
      byteData.setUint32(offset, entry.inlineValue!, Endian.little);
    } else if (entry.offsetValueBlock != null) {
      byteData.setUint32(offset, entry.offsetValueBlock!.offset, Endian.little);
    }

    offset += AppMath.bytesPerPixel;
  }

  byteData.setUint32(offset, TiffConstants.noValue, Endian.little);

  for (final _TiffDataBlock block in layout.blocks) {
    bytes.setRange(block.offset, block.offset + block.bytes.length, block.bytes);
  }
}

/// Returns the standard 8-bit RGBA bit-depth array used for TIFF pages.
List<int> _rgbaBitsPerSampleValues() {
  return List<int>.filled(
    TiffConstants.rgbaChannelCount,
    TiffConstants.bitsPerChannel,
    growable: false,
  );
}

/// Returns the unsigned-integer sample-format array used for TIFF RGBA pages.
List<int> _rgbaSampleFormatValues() {
  return List<int>.filled(
    TiffConstants.rgbaChannelCount,
    TiffConstants.sampleFormatUnsignedInteger,
    growable: false,
  );
}

/// Creates an inline SHORT TIFF entry.
_TiffTagEntry _shortValueEntry(final int tag, final int value) {
  return _TiffTagEntry(
    tag: tag,
    type: TiffConstants.typeShort,
    count: 1,
    inlineValue: value,
  );
}

/// Creates an inline LONG TIFF entry.
_TiffTagEntry _longValueEntry(final int tag, final int value) {
  return _TiffTagEntry(
    tag: tag,
    type: TiffConstants.typeLong,
    count: 1,
    inlineValue: value,
  );
}

/// Creates an offset-backed TIFF entry whose payload lives in a data block.
_TiffTagEntry _offsetBlockEntry(
  final int tag,
  final int type,
  final int count,
  final _TiffDataBlock block,
) {
  return _TiffTagEntry(
    tag: tag,
    type: type,
    count: count,
    offsetValueBlock: block,
  );
}

/// Creates a packed PageNumber TIFF entry containing the current and total page indices.
_TiffTagEntry _pageNumberEntry(final int currentPage, final int totalPages) {
  return _TiffTagEntry(
    tag: TiffConstants.tagPageNumber,
    type: TiffConstants.typeShort,
    count: TiffConstants.pageNumberCount,
    inlineBytes: _encodeShortValues(<int>[currentPage, totalPages]),
  );
}

/// Encodes a string TIFF entry using ASCII data storage.
_TiffTagEntry _asciiEntry(
  final int tag,
  final String text,
  final List<_TiffDataBlock> blocks,
) {
  final Uint8List data = _encodeAscii(text);
  return _inlineOrBlockEntry(
    tag: tag,
    type: TiffConstants.typeAscii,
    count: data.length,
    data: data,
    blocks: blocks,
  );
}

/// Encodes a SHORT array TIFF entry.
_TiffTagEntry _shortArrayEntry(
  final int tag,
  final List<int> values,
  final List<_TiffDataBlock> blocks,
) {
  final Uint8List data = _encodeShortValues(values);
  return _inlineOrBlockEntry(
    tag: tag,
    type: TiffConstants.typeShort,
    count: values.length,
    data: data,
    blocks: blocks,
  );
}

/// Encodes text as a NUL-terminated SHORT array for SketchBook layer-name tags.
_TiffTagEntry _shortTextEntry(
  final int tag,
  final String text,
  final List<_TiffDataBlock> blocks,
) {
  return _shortArrayEntry(
    tag,
    _encodeShortText(text),
    blocks,
  );
}

/// Encodes a RATIONAL TIFF entry backed by a separate data block.
_TiffTagEntry _rationalEntry(
  final int tag,
  final int numerator,
  final int denominator,
  final List<_TiffDataBlock> blocks,
) {
  final _TiffDataBlock block = _rationalBlock(numerator, denominator);
  blocks.add(block);
  return _offsetBlockEntry(tag, TiffConstants.typeRational, 1, block);
}

/// Stores small TIFF payloads inline and larger payloads in a referenced block.
_TiffTagEntry _inlineOrBlockEntry({
  required final int tag,
  required final int type,
  required final int count,
  required final Uint8List data,
  required final List<_TiffDataBlock> blocks,
}) {
  if (data.length <= AppMath.bytesPerPixel) {
    return _TiffTagEntry(
      tag: tag,
      type: type,
      count: count,
      inlineBytes: data,
    );
  }

  final _TiffDataBlock block = _TiffDataBlock(data);
  blocks.add(block);

  return _offsetBlockEntry(tag, type, count, block);
}

/// Encodes a list of integers as little-endian SHORT values.
Uint8List _encodeShortValues(final List<int> values) {
  final ByteData data = ByteData(values.length * AppMath.pair);
  int offset = TiffConstants.noValue;

  for (final int value in values) {
    data.setUint16(offset, value, Endian.little);
    offset += AppMath.pair;
  }

  return data.buffer.asUint8List();
}

/// Encodes a NUL-terminated UTF-16-like SHORT payload for SketchBook layer names.
List<int> _encodeShortText(final String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return <int>[TiffConstants.noValue];
  }

  return <int>[...trimmed.codeUnits, TiffConstants.noValue];
}

/// Encodes a canvas coordinate using SketchBook's fixed-point position scale.
int _encodeSketchBookPosition(final double coordinate) {
  return (coordinate * TiffConstants.sketchBookPositionDenominator).round();
}

/// Encodes a list of integers as little-endian LONG values.
Uint8List _encodeLongValues(final List<int> values) {
  final ByteData data = ByteData(values.length * AppMath.bytesPerPixel);
  int offset = TiffConstants.noValue;

  for (final int value in values) {
    data.setUint32(offset, value, Endian.little);
    offset += AppMath.bytesPerPixel;
  }

  return data.buffer.asUint8List();
}

/// Wraps a LONG array payload in a TIFF data block.
_TiffDataBlock _longArrayBlock(final List<int> values) {
  return _TiffDataBlock(_encodeLongValues(values));
}

/// Builds the raw RGBA pixel payload block for a TIFF page.
_TiffDataBlock _pixelBlock(
  final img.Image image, {
  required final bool writeBottomUp,
}) {
  return _TiffDataBlock(
    _encodeAssociatedRgbaPixels(
      image,
      writeBottomUp: writeBottomUp,
    ),
  );
}

/// Encodes a single RATIONAL payload into a TIFF data block.
_TiffDataBlock _rationalBlock(final int numerator, final int denominator) {
  final ByteData data = ByteData(TiffConstants.rationalSize);
  data.setUint32(TiffConstants.noValue, numerator, Endian.little);
  data.setUint32(AppMath.bytesPerPixel, denominator, Endian.little);
  return _TiffDataBlock(data.buffer.asUint8List());
}

/// Encodes bottom-up or top-down premultiplied RGBA pixels for TIFF storage.
Uint8List _encodeAssociatedRgbaPixels(
  final img.Image image, {
  required final bool writeBottomUp,
}) {
  final Uint8List pixelBytes = Uint8List(
    image.width * image.height * AppMath.bytesPerPixel,
  );
  int offset = TiffConstants.noValue;

  if (writeBottomUp) {
    for (int y = image.height - 1; y >= TiffConstants.noValue; y--) {
      for (int x = TiffConstants.noValue; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int alpha = pixel.a.toInt();
        pixelBytes[offset++] = _premultiplyChannel(pixel.r.toInt(), alpha);
        pixelBytes[offset++] = _premultiplyChannel(pixel.g.toInt(), alpha);
        pixelBytes[offset++] = _premultiplyChannel(pixel.b.toInt(), alpha);
        pixelBytes[offset++] = alpha;
      }
    }
    return pixelBytes;
  }

  for (int y = TiffConstants.noValue; y < image.height; y++) {
    for (int x = TiffConstants.noValue; x < image.width; x++) {
      final img.Pixel pixel = image.getPixel(x, y);
      final int alpha = pixel.a.toInt();
      pixelBytes[offset++] = _premultiplyChannel(pixel.r.toInt(), alpha);
      pixelBytes[offset++] = _premultiplyChannel(pixel.g.toInt(), alpha);
      pixelBytes[offset++] = _premultiplyChannel(pixel.b.toInt(), alpha);
      pixelBytes[offset++] = alpha;
    }
  }

  return pixelBytes;
}

/// Premultiplies one color channel against its alpha value.
int _premultiplyChannel(
  final int channel,
  final int alpha,
) {
  if (alpha <= TiffConstants.noValue) {
    return TiffConstants.noValue;
  }

  if (alpha >= AppLimits.rgbChannelMax) {
    return channel;
  }

  final int premultiplied = ((channel * alpha) / AppLimits.rgbChannelMax).round();
  return premultiplied.clamp(TiffConstants.noValue, AppLimits.rgbChannelMax).toInt();
}

/// Encodes a NUL-terminated ASCII payload for TIFF text fields.
Uint8List _encodeAscii(final String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) {
    return Uint8List(TiffConstants.noValue);
  }

  return Uint8List.fromList(<int>[...trimmed.codeUnits, TiffConstants.noValue]);
}

/// A deferred TIFF payload block that is written after the directory entries.
class _TiffDataBlock {
  _TiffDataBlock(this.bytes);

  final Uint8List bytes;
  int offset = TiffConstants.noValue;
}

/// A single TIFF directory entry and its inline or block-backed value.
class _TiffTagEntry {
  _TiffTagEntry({
    required this.tag,
    required this.type,
    required this.count,
    this.inlineValue,
    this.inlineBytes,
    this.offsetValueBlock,
  });

  final int tag;
  final int type;
  final int count;
  int? inlineValue;
  Uint8List? inlineBytes;
  _TiffDataBlock? offsetValueBlock;
}

/// A precomputed TIFF directory with its referenced data blocks.
class _TiffDirectoryLayout {
  _TiffDirectoryLayout({
    required final List<_TiffTagEntry> entries,
    required this.blocks,
    this.subIfdEntry,
    this.subIfdBlock,
  }) : entries = (List<_TiffTagEntry>.from(entries)
         ..sort((final _TiffTagEntry a, final _TiffTagEntry b) => a.tag.compareTo(b.tag))),
       ifdSize = TiffConstants.ifdCountSize + entries.length * TiffConstants.ifdEntrySize + TiffConstants.nextIfdSize,
       totalByteSize =
           TiffConstants.ifdCountSize +
           entries.length * TiffConstants.ifdEntrySize +
           TiffConstants.nextIfdSize +
           blocks.fold<int>(
             TiffConstants.noValue,
             (final int total, final _TiffDataBlock block) => total + block.bytes.length,
           );

  final List<_TiffTagEntry> entries;
  final List<_TiffDataBlock> blocks;
  final _TiffTagEntry? subIfdEntry;
  final _TiffDataBlock? subIfdBlock;
  final int ifdSize;
  final int totalByteSize;
  int startOffset = TiffConstants.noValue;

  /// Assigns absolute output offsets to each deferred block in the directory.
  void assignBlockOffsets() {
    int nextOffset = startOffset + ifdSize;

    for (final _TiffDataBlock block in blocks) {
      block.offset = nextOffset;
      nextOffset += block.bytes.length;
    }
  }

  /// Writes the final SubIFD offsets into the root SubIFD payload block.
  void populateSubIfdOffsets(final List<int> offsets) {
    if (subIfdEntry == null || subIfdBlock == null) {
      return;
    }

    final ByteData data = ByteData.sublistView(subIfdBlock!.bytes);
    int offset = TiffConstants.noValue;

    for (final int subIfdOffset in offsets) {
      data.setUint32(offset, subIfdOffset, Endian.little);
      offset += AppMath.bytesPerPixel;
    }

    if (offsets.length == 1) {
      subIfdEntry!.inlineBytes = Uint8List.fromList(subIfdBlock!.bytes);
      subIfdEntry!.offsetValueBlock = null;
    }
  }
}
