import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

final Logger _log = Logger(logNameFileHeic);

const String _errorConvertPrefix = 'Failed to decode HEIC image';
const String _errorEncodePrefix = 'Failed to encode HEIC image';
const String _errorCanvasContext = 'Failed to get canvas context';
const String _errorDisplayReturnedNull = 'HEIF processing error: display returned null';
const String _errorInvalidImageDimensionsPrefix = 'Invalid image dimensions:';
const String _errorNoValidImages = 'No valid images found in HEIC file';
const String _errorScriptLoadPrefix = 'Failed to load script:';
const String _canvasContext2d = '2d';
const String _dataUrlSeparator = ',';
const String _eventError = 'error';
const String _eventLoad = 'load';
const String _globalLibheifModule = 'libheifModule';
const String _libheifBundleUrl = 'https://cdn.jsdelivr.net/npm/libheif-js@1.19.8/libheif-wasm/libheif-bundle.js';
const String _mimeTypePng = 'image/png';
const String _scriptTypeJavascript = 'application/javascript';

Future<void>? _libheifLoadFuture;

@JS('libheif')
external JSObject _createLibheifModule();

extension type _HeifImage._(JSObject _) implements JSObject {
  @JS('get_width')
  external int _getWidth();

  @JS('get_height')
  external int _getHeight();

  external void _display(JSObject displayData, JSFunction callback);

  external void _free();
}

@JS('libheifModule.HeifDecoder')
extension type _HeifDecoder._(JSObject _) implements JSObject {
  external _HeifDecoder();

  external JSArray<_HeifImage> _decode(JSUint8Array data);
}

/// HEIC export encoding is not supported on the web platform.
bool get isHeicExportSupported => false;

/// Converts HEIC bytes into PNG bytes using a minimal libheif-js bridge.
Future<Uint8List> decodeHeicBytes(final Uint8List heicBytes) async {
  await _ensureLibheifLoaded();

  try {
    final _HeifDecoder decoder = _HeifDecoder();
    final List<_HeifImage> images = decoder._decode(heicBytes.toJS).toDart;
    if (images.isEmpty) {
      throw const HeicConversionException(_errorNoValidImages);
    }

    final _HeifImage image = images.first;
    try {
      final int width = image._getWidth();
      final int height = image._getHeight();
      if (width <= 0 || height <= 0) {
        throw HeicConversionException(
          '$_errorInvalidImageDimensionsPrefix width=$width, height=$height',
        );
      }

      final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
        ..width = width
        ..height = height;
      final web.CanvasRenderingContext2D? context =
          canvas.getContext(_canvasContext2d) as web.CanvasRenderingContext2D?;
      if (context == null) {
        throw const HeicConversionException(_errorCanvasContext);
      }

      final web.ImageData imageData = context.createImageData(width.toJS, height);
      final Completer<void> completer = Completer<void>();

      void displayCallback(final JSObject? displayData) {
        if (displayData == null) {
          if (!completer.isCompleted) {
            completer.completeError(
              const HeicConversionException(_errorDisplayReturnedNull),
            );
          }
          return;
        }

        if (!completer.isCompleted) {
          completer.complete();
        }
      }

      image._display(imageData, displayCallback.toJS);
      await completer.future;
      context.putImageData(imageData, 0, 0);

      final String dataUrl = canvas.toDataUrl(_mimeTypePng);
      final String base64Data = dataUrl.split(_dataUrlSeparator).last;
      return base64Decode(base64Data);
    } finally {
      image._free();
    }
  } catch (e) {
    if (e is HeicConversionException) {
      rethrow;
    }
    throw HeicConversionException(_errorConvertPrefix, cause: e);
  }
}

/// HEIC encoding is not supported on web.
///
/// Always throws [HeicConversionException].
Future<Uint8List> encodeToHeic(final Uint8List _) async {
  throw const HeicConversionException(_errorEncodePrefix);
}

/// Ensures the libheif-js runtime is present before web HEIC decoding starts.
Future<void> _ensureLibheifLoaded() async {
  if (_isLibheifAvailable()) {
    return;
  }

  _libheifLoadFuture ??= _loadLibheifScript();
  try {
    await _libheifLoadFuture;
  } catch (e, stackTrace) {
    _log.warning('Failed to load libheif-js runtime', e, stackTrace);
    _libheifLoadFuture = null;
    rethrow;
  }
}

bool _isLibheifAvailable() {
  return globalContext.hasProperty(_globalLibheifModule.toJS).toDart;
}

/// Loads libheif-js once and initializes the global decoder module.
Future<void> _loadLibheifScript() {
  final web.HTMLHeadElement? head = web.document.head;
  if (head == null) {
    throw const HeicConversionException(_errorConvertPrefix);
  }

  final web.HTMLScriptElement script = web.HTMLScriptElement()
    ..type = _scriptTypeJavascript
    ..src = _libheifBundleUrl
    ..defer = true;
  final Completer<void> completer = Completer<void>();

  script.addEventListener(
    _eventLoad,
    (final web.Event _) {
      globalContext[_globalLibheifModule] = _createLibheifModule();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }.toJS,
  );

  script.addEventListener(
    _eventError,
    (final web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const HeicConversionException('$_errorScriptLoadPrefix $_libheifBundleUrl'),
        );
      }
    }.toJS,
  );

  head.append(script);
  return completer.future;
}
