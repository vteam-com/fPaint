part of 'smudge_helper.dart';

// ---------------------------------------------------------------------------
// Profiling instrumentation (temporary experiment)
// ---------------------------------------------------------------------------

class _ProfStat {
  // Debug-summary label fragments, kept as constants so the formatted output
  // carries no raw user-facing string literals.
  static const String _countLabel = 'n=';
  static const String _avgLabel = ' avg=';
  static const String _maxLabel = ' max=';
  static const String _totalLabel = ' total=';
  static const String _msUnit = 'ms';

  int count = 0;
  int totalMicros = 0;
  int maxMicros = 0;

  /// Records one timing sample of [micros] microseconds.
  void add(final int micros) {
    count++;
    totalMicros += micros;
    if (micros > maxMicros) {
      maxMicros = micros;
    }
  }

  /// Returns a one-line summary (count, average, max and total in ms).
  String format() {
    const int microsPerMilli = Duration.microsecondsPerMillisecond;
    final double avgMs = count == 0 ? 0 : (totalMicros / count / microsPerMilli);
    return '$_countLabel$count'
        '$_avgLabel${avgMs.toStringAsFixed(AppMath.two)}$_msUnit'
        '$_maxLabel${(maxMicros / microsPerMilli).toStringAsFixed(AppMath.two)}$_msUnit'
        '$_totalLabel${(totalMicros / microsPerMilli).toStringAsFixed(0)}$_msUnit';
  }
}

/// Lightweight aggregating profiler for the pixel-brush pipeline. Flip
/// [enabled] to true while diagnosing stroke performance; it must stay false
/// in shipping builds so no `Stopwatch` allocation, `record` bookkeeping, or
/// per-stroke `debugPrint` runs on the interaction hot path.
class PixelBrushProfiler {
  PixelBrushProfiler._();

  /// Whether profiling instrumentation is active. Off by default; callers must
  /// gate every hot-path `Stopwatch` construction on this flag so a disabled
  /// profiler has zero cost (see usages in the canvas gesture handlers).
  // Off by default so no Stopwatch/record/debugPrint runs on the interaction hot
  // path in shipping builds. Flip to true (or `kProfileMode`) locally to profile
  // a stroke; run `flutter run --profile` and read the `[PixelBrushProfile]`
  // console summary printed at stroke end.
  static bool enabled = false;

  static final Map<String, _ProfStat> _stats = <String, _ProfStat>{};
  static final Stopwatch _wall = Stopwatch();
  static final Stopwatch _sinceLastKick = Stopwatch();
  static int _kicks = 0;
  static int _totalPoints = 0;
  static int _maxPoints = 0;
  static int _maxPatchPixels = 0;
  static int _moves = 0;
  static int _kickAttempts = 0;
  static int _skipBusy = 0;
  static int _skipFewPoints = 0;
  static int _exceptions = 0;

  /// Resets all counters and starts the wall-clock timers for a new stroke.
  static void beginStroke() {
    if (!enabled) {
      return;
    }
    _stats.clear();
    _kicks = 0;
    _totalPoints = 0;
    _maxPoints = 0;
    _maxPatchPixels = 0;
    _moves = 0;
    _kickAttempts = 0;
    _skipBusy = 0;
    _skipFewPoints = 0;
    _exceptions = 0;
    _wall
      ..reset()
      ..start();
    _sinceLastKick
      ..reset()
      ..start();
  }

  /// Counts one pointer-move event received during the stroke.
  static void recordMove() {
    if (enabled) {
      _moves++;
    }
  }

  /// Counts one attempt to kick off a segment computation.
  static void recordKickAttempt() {
    if (enabled) {
      _kickAttempts++;
    }
  }

  /// Counts one segment skipped because a prior computation was still in flight.
  static void recordSkipBusy() {
    if (enabled) {
      _skipBusy++;
    }
  }

  /// Counts one segment skipped for having too few points to process.
  static void recordSkipFewPoints() {
    if (enabled) {
      _skipFewPoints++;
    }
  }

  /// Counts one exception thrown while processing the stroke.
  static void recordException() {
    if (enabled) {
      _exceptions++;
    }
  }

  /// Records the gap since the previous kick actually started work.
  static void markKickStart() {
    if (!enabled) {
      return;
    }
    record('kickGap', _sinceLastKick.elapsedMicroseconds);
    _sinceLastKick
      ..reset()
      ..start();
  }

  /// Records a [micros] timing sample under the bucket named [name].
  static void record(final String name, final int micros) {
    if (!enabled) {
      return;
    }
    (_stats[name] ??= _ProfStat()).add(micros);
  }

  /// Returns a started [Stopwatch] when profiling is [enabled], otherwise null.
  ///
  /// Hot-path callers use this (paired with [recordElapsed]) so a disabled
  /// profiler performs no allocation or timing syscalls on the interaction path.
  static Stopwatch? startWatch() => enabled ? (Stopwatch()..start()) : null;

  /// Stops [watch] and records its elapsed time under [name] when non-null.
  static void recordElapsed(final String name, final Stopwatch? watch) {
    if (watch == null) {
      return;
    }
    watch.stop();
    record(name, watch.elapsedMicroseconds);
  }

  /// Records one processed segment of [pointCount] points that touched
  /// [patchPixels] pixels.
  static void recordSegment(final int pointCount, final int patchPixels) {
    if (!enabled) {
      return;
    }
    _kicks++;
    _totalPoints += pointCount;
    if (pointCount > _maxPoints) {
      _maxPoints = pointCount;
    }
    if (patchPixels > _maxPatchPixels) {
      _maxPatchPixels = patchPixels;
    }
  }

  /// Stops timing and prints the aggregated per-stroke summary via [debugPrint].
  static void endStroke() {
    if (!enabled || !_wall.isRunning) {
      return;
    }
    _wall.stop();
    debugPrint(
      '[PixelBrushProfile] stroke wall=${_wall.elapsedMilliseconds}ms moves=$_moves '
      'kickAttempts=$_kickAttempts kicks=$_kicks skip(busy=$_skipBusy fewPts=$_skipFewPoints) '
      'exceptions=$_exceptions points(total=$_totalPoints maxPerSeg=$_maxPoints) maxPatchPx=$_maxPatchPixels',
    );
    _stats.forEach((final String name, final _ProfStat stat) {
      debugPrint('[PixelBrushProfile]   $name: ${stat.format()}');
    });
  }
}
