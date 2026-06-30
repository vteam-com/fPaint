part of 'smudge_helper.dart';

// ---------------------------------------------------------------------------
// Persistent per-stroke worker isolate
// ---------------------------------------------------------------------------

// Worker-isolate message-type tags. Shared by [PixelBrushStrokeWorker] and
// [_pixelBrushWorkerEntry] so the command names cannot drift apart. These are
// internal protocol identifiers and are never shown to the user.
const String _workerMsgInit = 'init';
const String _workerMsgSegment = 'segment';
const String _workerMsgFinalize = 'finalize';
const String _workerMsgDispose = 'dispose';

/// Profiler bucket label for the segment send/receive round-trip.
const String _profLabelRoundtrip = 'roundtrip';

/// A long-lived isolate that owns the full pixel buffer for the duration of a
/// single pixel-brush stroke.
///
/// Spawned once per stroke (not per pointer-move), it keeps the accumulating
/// image buffer in the background isolate so each update only sends the new
/// segment points across the port and receives back the small dirty-rect patch
/// — never the full image. The heavy per-pixel blending therefore never blocks
/// the UI isolate, and there is no per-move isolate spawn or full-buffer copy.
///
/// The caller must serialize calls (one in-flight [applySegment]/[finalize] at
/// a time); the gesture handler already enforces this with its busy flag.
class PixelBrushStrokeWorker {
  PixelBrushStrokeWorker._(this._isolate, this._receivePort) {
    _subscription = _receivePort.listen(_handleMessage);
  }

  final Isolate _isolate;
  final ReceivePort _receivePort;
  late final StreamSubscription<dynamic> _subscription;
  final Completer<void> _ready = Completer<void>();
  late final SendPort _commandPort;
  final Map<int, Completer<Map<String, Object?>>> _pending = <int, Completer<Map<String, Object?>>>{};
  int _nextId = 0;
  bool _disposed = false;

  /// Spawns and initializes a worker holding [basePixels]. Returns `null` on
  /// web (isolates unavailable) or if spawning fails, so callers fall back to
  /// the synchronous path.
  static Future<PixelBrushStrokeWorker?> start({
    required final Uint8List basePixels,
    required final int imageWidth,
    required final int imageHeight,
    final Uint8List? clipMask,
  }) async {
    if (kIsWeb) {
      return null;
    }
    try {
      final Stopwatch? startupWatch = PixelBrushProfiler.startWatch();
      final ReceivePort receivePort = ReceivePort();
      final Isolate isolate = await Isolate.spawn(_pixelBrushWorkerEntry, receivePort.sendPort);
      final PixelBrushStrokeWorker worker = PixelBrushStrokeWorker._(isolate, receivePort);
      await worker._ready.future;
      worker._commandPort.send(<String, Object?>{
        'type': _workerMsgInit,
        'pixels': TransferableTypedData.fromList(<Uint8List>[basePixels]),
        'clipMask': clipMask == null ? null : TransferableTypedData.fromList(<Uint8List>[clipMask]),
        'width': imageWidth,
        'height': imageHeight,
      });
      PixelBrushProfiler.recordElapsed('workerStartup', startupWatch);
      return worker;
    } on Object {
      return null;
    }
  }

  /// Routes a message from the worker isolate: the first one is the command
  /// [SendPort] (completes [_ready]); every later one is a reply keyed by `id`
  /// that completes the matching pending request.
  void _handleMessage(final dynamic message) {
    if (message is SendPort) {
      _commandPort = message;
      _ready.complete();
      return;
    }
    final Map<String, Object?> reply = message as Map<String, Object?>;
    final int id = reply['id']! as int;
    _pending.remove(id)?.complete(reply);
  }

  Future<Map<String, Object?>> _send(final Map<String, Object?> message) {
    final int id = _nextId++;
    final Completer<Map<String, Object?>> completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    message['id'] = id;
    _commandPort.send(message);
    return completer.future;
  }

  /// Applies [segmentPoints] to the retained buffer and returns the dirty-rect
  /// patch bounded by [patchBounds], or `null` when nothing changed.
  Future<PixelBrushPatchUpdate?> applySegment({
    required final List<Offset> segmentPoints,
    required final double brushSize,
    required final double intensity,
    required final PixelBrushMode mode,
    required final ui.Rect patchBounds,
  }) async {
    if (_disposed) {
      return null;
    }
    final Float64List encoded = Float64List(segmentPoints.length * AppMath.pair);
    for (int i = AppMath.zero; i < segmentPoints.length; i++) {
      encoded[i * AppMath.pair] = segmentPoints[i].dx;
      encoded[i * AppMath.pair + AppMath.one] = segmentPoints[i].dy;
    }
    final Stopwatch? roundtripWatch = PixelBrushProfiler.startWatch();
    final Map<String, Object?> reply = await _send(<String, Object?>{
      'type': _workerMsgSegment,
      'points': encoded,
      'brushSize': brushSize,
      'intensity': intensity,
      'mode': mode.index,
      'pl': patchBounds.left,
      'pt': patchBounds.top,
      'pr': patchBounds.right,
      'pb': patchBounds.bottom,
    });
    roundtripWatch?.stop();
    final int roundtripMicros = roundtripWatch?.elapsedMicroseconds ?? AppMath.zero;
    PixelBrushProfiler.record(_profLabelRoundtrip, roundtripMicros);
    final Object? computeMicros = reply['computeMicros'];
    if (computeMicros is int) {
      PixelBrushProfiler.record('isolateCompute', computeMicros);
      // Round-trip minus compute ≈ messaging/transfer/scheduling overhead.
      PixelBrushProfiler.record('roundtripOverhead', roundtripMicros - computeMicros);
    }
    if (reply['hasChanges'] != true) {
      PixelBrushProfiler.recordSegment(segmentPoints.length, AppMath.zero);
      return null;
    }
    final int width = reply['width']! as int;
    final int height = reply['height']! as int;
    PixelBrushProfiler.recordSegment(segmentPoints.length, width * height);
    return PixelBrushPatchUpdate(
      pixels: (reply['patch']! as TransferableTypedData).materialize().asUint8List(),
      left: reply['left']! as int,
      top: reply['top']! as int,
      width: width,
      height: height,
    );
  }

  /// Returns the full accumulated pixel buffer for committing the stroke.
  Future<Uint8List?> finalizePixels() async {
    if (_disposed) {
      return null;
    }
    final Map<String, Object?> reply = await _send(<String, Object?>{'type': _workerMsgFinalize});
    return (reply['pixels']! as TransferableTypedData).materialize().asUint8List();
  }

  /// Tears down the worker isolate. Safe to call multiple times.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _subscription.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final Completer<Map<String, Object?>> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(<String, Object?>{'hasChanges': false});
      }
    }
    _pending.clear();
  }
}

/// Entry point for [PixelBrushStrokeWorker]. Owns the stroke's pixel buffer and
/// services segment / finalize requests until disposed.
void _pixelBrushWorkerEntry(final SendPort mainSendPort) {
  final ReceivePort commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  Uint8List? pixels;
  Uint8List? clipMask;
  int width = AppMath.zero;
  int height = AppMath.zero;

  commandPort.listen((final dynamic message) {
    final Map<String, Object?> map = message as Map<String, Object?>;
    switch (map['type']) {
      case _workerMsgInit:
        pixels = (map['pixels']! as TransferableTypedData).materialize().asUint8List();
        final TransferableTypedData? mask = map['clipMask'] as TransferableTypedData?;
        clipMask = mask?.materialize().asUint8List();
        width = map['width']! as int;
        height = map['height']! as int;
      case _workerMsgSegment:
        final int id = map['id']! as int;
        final Float64List encoded = map['points']! as Float64List;
        final List<Offset> segmentPoints = <Offset>[
          for (int i = AppMath.zero; i < encoded.length; i += AppMath.pair)
            Offset(encoded[i], encoded[i + AppMath.one]),
        ];
        final Stopwatch computeWatch = Stopwatch()..start();
        final _PixelBrushComputationResult result = _runPixelBrushComputation(
          livePixels: pixels!,
          clipMask: clipMask,
          imageWidth: width,
          imageHeight: height,
          segmentPoints: segmentPoints,
          brushSize: map['brushSize']! as double,
          intensity: map['intensity']! as double,
          mode: PixelBrushMode.values[map['mode']! as int],
        );
        computeWatch.stop();
        final int computeMicros = computeWatch.elapsedMicroseconds;
        if (!result.hasChanges) {
          mainSendPort.send(<String, Object?>{'id': id, 'hasChanges': false, 'computeMicros': computeMicros});
          break;
        }
        final int left = math.max(AppMath.zero, (map['pl']! as double).floor());
        final int top = math.max(AppMath.zero, (map['pt']! as double).floor());
        final int right = math.min(width, (map['pr']! as double).ceil());
        final int bottom = math.min(height, (map['pb']! as double).ceil());
        final int patchWidth = right - left;
        final int patchHeight = bottom - top;
        if (patchWidth <= AppMath.zero || patchHeight <= AppMath.zero) {
          mainSendPort.send(<String, Object?>{'id': id, 'hasChanges': false});
          break;
        }
        final Uint8List patch = _copyPixelRect(
          pixels: pixels!,
          imageWidth: width,
          left: left,
          top: top,
          width: patchWidth,
          height: patchHeight,
        );
        mainSendPort.send(<String, Object?>{
          'id': id,
          'hasChanges': true,
          'patch': TransferableTypedData.fromList(<Uint8List>[patch]),
          'left': left,
          'top': top,
          'width': patchWidth,
          'height': patchHeight,
          'computeMicros': computeMicros,
        });
      case _workerMsgFinalize:
        final int id = map['id']! as int;
        mainSendPort.send(<String, Object?>{
          'id': id,
          'pixels': TransferableTypedData.fromList(<Uint8List>[pixels!]),
        });
      case _workerMsgDispose:
        commandPort.close();
    }
  });
}
