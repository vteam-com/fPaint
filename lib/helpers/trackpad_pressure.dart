import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/stylus_pressure.dart';

const String _channelName = 'com.vteam.fpaint/trackpad';
const String _pressureMethod = 'pressure';
const MethodChannel _channel = MethodChannel(_channelName);

/// Latest Force Touch trackpad pressure pushed by the macOS runner.
///
/// Flutter's desktop embedder drops pointer pressure, so the runner watches
/// `NSEvent` pressure events and forwards a normalized 0..1 value while the
/// trackpad is clicked down (null once it is released). A plain mouse never
/// produces pressure events, so it stays null and paints at constant width.
class TrackpadPressure {
  TrackpadPressure._();

  /// The process-wide pressure tracker.
  static final TrackpadPressure instance = TrackpadPressure._();

  double? _pressure;

  /// Whether this platform can report trackpad pressure.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// The latest pressure (0..1) of the held trackpad click, shaped by
  /// [AppInteraction.trackpadPressureCurveExponent], or null when none.
  double? get pressure => _pressure;

  /// Starts receiving pressure updates from the macOS runner.
  void listen() {
    if (!isSupported) {
      return;
    }
    _channel.setMethodCallHandler(handleMethodCall);
  }

  /// Applies one pressure update from the runner.
  @visibleForTesting
  Future<void> handleMethodCall(MethodCall call) async {
    if (call.method != _pressureMethod) {
      return;
    }
    final Object? raw = call.arguments;
    _pressure = raw is num
        ? pow(
            raw.toDouble().clamp(AppMath.zero.toDouble(), AppMath.one.toDouble()),
            AppInteraction.trackpadPressureCurveExponent,
          ).toDouble()
        : null;
  }

  /// Clears the held pressure.
  @visibleForTesting
  void reset() {
    _pressure = null;
  }
}

/// Whether a Brush stroke from [event] should follow the Force Touch trackpad
/// pressure: the setting is on, the platform supports it, and the pointer is
/// the mouse-kind pointer macOS reports for trackpad clicks.
bool usesTrackpadPressure(PointerEvent event, {required bool enabled}) {
  return enabled && TrackpadPressure.isSupported && event.kind == PointerDeviceKind.mouse;
}

/// Returns the normalized pressure for a Brush [event]: the stylus pen
/// pressure, else the held trackpad pressure when [usesTrackpadPressure]
/// applies, else null (constant width).
double? brushPointerPressure(PointerEvent event, {required bool trackpadPressureEnabled}) {
  final double? penPressure = stylusPressure(event);
  if (penPressure != null) {
    return penPressure;
  }
  return usesTrackpadPressure(event, enabled: trackpadPressureEnabled) ? TrackpadPressure.instance.pressure : null;
}
