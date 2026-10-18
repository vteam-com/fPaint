import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/foundation.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';

/// The eight-byte PNG file signature.
const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// ASCII chunk type tags.
const List<int> _chunkIhdr = <int>[0x49, 0x48, 0x44, 0x52];
const List<int> _chunkIdat = <int>[0x49, 0x44, 0x41, 0x54];
const List<int> _chunkIend = <int>[0x49, 0x45, 0x4E, 0x44];

/// IHDR fields: 8-bit samples, RGBA colour type, deflate, adaptive filtering
/// method 0, no interlace.
const int _bitDepth = 8;
const int _colorTypeRgba = 6;
const int _compressionDeflate = 0;
const int _filterMethodAdaptive = 0;
const int _interlaceNone = 0;

/// Length of the IHDR payload in bytes.
const int _ihdrLength = 13;

/// Per-row filter type "Sub": each byte minus the same channel one pixel left.
const int _filterSub = 1;

/// Bytes per RGBA pixel.
const int _bytesPerPixel = 4;

/// Bytes in a chunk's length, type and CRC fields.
const int _chunkFieldBytes = 4;

/// Bit shifts and mask for writing a big-endian 32-bit integer.
const int _shift24 = 24;
const int _shift16 = 16;
const int _shift8 = 8;
const int _byteMask = 0xFF;

/// zlib level for encoded images.
///
/// Measured on a 68 MP five-layer painting: level 4 encodes about four times
/// faster than the engine's default (6) for files about 8% larger; level 1 is
/// only ~40% faster again but 25% larger. The pixels are lossless at any level.
const int _defaultDeflateLevel = 4;

/// Pixel budget for parallel encodes on desktop (about 1 GB of readbacks).
const int _desktopPixelBudget = 200000000;

/// Pixel budget for parallel encodes on mobile.
const int _mobilePixelBudget = 16000000;

/// Filtered bytes handed to zlib per call.
const int _deflateChunkBytes = 4 * 1024 * 1024;

/// Encodes [image] as a lossless PNG off the main isolate.
///
/// The engine's PNG encoder runs on one thread at its default compression, so
/// a 68 MP layer takes many seconds and layers queue behind each other. Here
/// only the straight-alpha readback touches the engine (tens of ms); the
/// filtering and deflate run in a worker isolate with native zlib, so several
/// images encode in parallel. With [disposeAfterReadback] the GPU image is
/// released as soon as its pixels are read, before the encode. Web has no
/// isolates or native zlib and keeps the engine encoder.
Future<Uint8List?> encodeImageToPngFast(ui.Image image, {bool disposeAfterReadback = false}) async {
  final int width = image.width;
  final int height = image.height;
  final ByteData? rgba;
  try {
    if (kIsWeb) {
      return await encodeImageToPng(image);
    }
    rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  } finally {
    if (disposeAfterReadback) {
      image.dispose();
    }
  }
  if (rgba == null) {
    return null;
  }
  final TransferableTypedData pixels = TransferableTypedData.fromList(<TypedData>[rgba]);
  return Isolate.run(
    () => encodeStraightRgbaPng(
      rgba: pixels.materialize().asUint8List(),
      width: width,
      height: height,
    ),
  );
}

/// Bounds how many image pixels are being encoded at once, so parallel
/// encodes cannot exhaust memory: a job waits until its pixels fit within
/// [pixelBudget] alongside the running ones (a lone job always runs).
class PngEncodePool {
  PngEncodePool({required this.pixelBudget});

  /// Most source pixels in flight across running jobs.
  final int pixelBudget;

  int _pixelsInFlight = AppMath.zero;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  /// The budget for this platform: generous on desktop, effectively serial
  /// for large canvases on mobile, whose per-app memory limit parallel
  /// exports used to overrun during draft autosave.
  static int get platformPixelBudget =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid) ? _mobilePixelBudget : _desktopPixelBudget;

  /// Runs [job], which works on [pixels] source pixels, once they fit the
  /// budget.
  Future<T> run<T>(int pixels, Future<T> Function() job) async {
    while (_pixelsInFlight > AppMath.zero && _pixelsInFlight + pixels > pixelBudget) {
      final Completer<void> slot = Completer<void>();
      _waiters.add(slot);
      await slot.future;
    }
    _pixelsInFlight += pixels;
    try {
      return await job();
    } finally {
      _pixelsInFlight -= pixels;
      final List<Completer<void>> waiting = List<Completer<void>>.of(_waiters);
      _waiters.clear();
      for (final Completer<void> slot in waiting) {
        slot.complete();
      }
    }
  }
}

/// Encodes [width] x [height] straight (non-premultiplied) RGBA [rgba] as a
/// PNG, filtering every row with "Sub" and deflating at [level].
///
/// Rows are filtered into a small scratch buffer and streamed into zlib, so
/// encoding needs no second full-size copy of the pixels.
Uint8List encodeStraightRgbaPng({
  required Uint8List rgba,
  required int width,
  required int height,
  int level = _defaultDeflateLevel,
}) {
  final int stride = width * _bytesPerPixel;
  final int filteredStride = stride + AppMath.one;
  final int rowsPerChunk = max(AppMath.one, _deflateChunkBytes ~/ filteredStride);
  final Uint8List scratch = Uint8List(filteredStride * rowsPerChunk);

  late final Uint8List deflated;
  final ByteConversionSink zlib = ZLibEncoder(level: level).startChunkedConversion(
    ByteConversionSink.withCallback(
      (List<int> bytes) => deflated = bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    ),
  );
  int rowsInScratch = AppMath.zero;
  for (int y = AppMath.zero; y < height; y++) {
    final int row = y * stride;
    int out = rowsInScratch * filteredStride;
    scratch[out++] = _filterSub;
    for (int i = AppMath.zero; i < _bytesPerPixel; i++) {
      scratch[out++] = rgba[row + i];
    }
    for (int i = _bytesPerPixel; i < stride; i++) {
      scratch[out++] = (rgba[row + i] - rgba[row + i - _bytesPerPixel]) & _byteMask;
    }
    rowsInScratch++;
    if (rowsInScratch == rowsPerChunk || y == height - AppMath.one) {
      zlib.addSlice(scratch, AppMath.zero, rowsInScratch * filteredStride, false);
      rowsInScratch = AppMath.zero;
    }
  }
  zlib.close();

  final BytesBuilder png = BytesBuilder(copy: false)..add(_pngSignature);
  final Uint8List header = Uint8List(_ihdrLength);
  final ByteData headerView = ByteData.sublistView(header)
    ..setUint32(AppMath.zero, width)
    ..setUint32(_chunkFieldBytes, height);
  int field = _chunkFieldBytes * AppMath.pair;
  for (final int value in <int>[
    _bitDepth,
    _colorTypeRgba,
    _compressionDeflate,
    _filterMethodAdaptive,
    _interlaceNone,
  ]) {
    headerView.setUint8(field++, value);
  }
  _addChunk(png, _chunkIhdr, header);
  _addChunk(png, _chunkIdat, deflated);
  _addChunk(png, _chunkIend, Uint8List(AppMath.zero));
  return png.takeBytes();
}

/// Appends one PNG chunk: length, type, [data], and the CRC of type + data.
void _addChunk(BytesBuilder png, List<int> type, Uint8List data) {
  png
    ..add(_uint32(data.length))
    ..add(type)
    ..add(data)
    ..add(_uint32(getCrc32(data, getCrc32(type))));
}

/// [value] as four big-endian bytes.
Uint8List _uint32(int value) {
  return Uint8List.fromList(<int>[
    (value >> _shift24) & _byteMask,
    (value >> _shift16) & _byteMask,
    (value >> _shift8) & _byteMask,
    value & _byteMask,
  ]);
}
