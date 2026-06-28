import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/wand_selection_request.dart';

export 'package:fpaint/providers/wand_selection_request.dart';

/// Owns the magic-wand selection request queue and the rasterized source cache.
///
/// Extracting this state out of `AppProvider` keeps wand request sequencing and
/// pixel caching together as a single, testable responsibility instead of a
/// loose cluster of public fields on the app-wide provider.
class WandSelectionManager {
  /// Whether a magic-wand computation is currently running.
  bool isInProgress = false;

  int _requestVersion = AppMath.zero;
  Offset? _pendingPosition;
  bool _pendingSampleAllLayers = false;

  int _cachedSignature = -AppMath.one;
  Uint8List? _cachedPixels;
  int _cachedWidth = AppMath.zero;
  int _cachedHeight = AppMath.zero;

  /// Monotonic token that invalidates stale async magic-wand computations.
  int get requestVersion => _requestVersion;

  /// Whether a request is waiting to be processed.
  bool get hasPendingRequest => _pendingPosition != null;

  /// Queues a new request, invalidating any older in-flight result.
  void queueRequest({
    required final Offset position,
    required final bool sampleAllLayers,
  }) {
    _requestVersion += AppMath.one;
    _pendingPosition = position;
    _pendingSampleAllLayers = sampleAllLayers;
  }

  /// Takes the queued request (if any), clearing it from the queue.
  WandSelectionRequest? takePendingRequest() {
    final Offset? position = _pendingPosition;
    if (position == null) {
      return null;
    }
    final WandSelectionRequest request = WandSelectionRequest(
      position: position,
      sampleAllLayers: _pendingSampleAllLayers,
      version: _requestVersion,
    );
    _pendingPosition = null;
    _pendingSampleAllLayers = false;
    return request;
  }

  /// Invalidates any queued request without touching the cached raster.
  void cancelPendingRequest() {
    _requestVersion += AppMath.one;
    _pendingPosition = null;
    _pendingSampleAllLayers = false;
  }

  /// Fully resets the queue and drops the cached source raster.
  void reset() {
    cancelPendingRequest();
    clearCache();
  }

  /// Drops the cached source raster so the next request re-samples pixels.
  void clearCache() {
    _cachedSignature = -AppMath.one;
    _cachedPixels = null;
    _cachedWidth = AppMath.zero;
    _cachedHeight = AppMath.zero;
  }

  /// Returns the cached source data when [signature] still matches, else null.
  FillImageData? cachedImageData(final int signature) {
    if (signature == _cachedSignature &&
        _cachedPixels != null &&
        _cachedWidth > AppMath.zero &&
        _cachedHeight > AppMath.zero) {
      return FillImageData(
        pixels: _cachedPixels!,
        width: _cachedWidth,
        height: _cachedHeight,
      );
    }
    return null;
  }

  /// Stores freshly rasterized source pixels under [signature].
  void storeCache({
    required final int signature,
    required final Uint8List pixels,
    required final int width,
    required final int height,
  }) {
    _cachedSignature = signature;
    _cachedPixels = pixels;
    _cachedWidth = width;
    _cachedHeight = height;
  }
}
