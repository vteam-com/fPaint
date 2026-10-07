import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/trackpad_pressure.dart';

const PointerDownEvent _mouseDown = PointerDownEvent(kind: PointerDeviceKind.mouse);
const PointerDownEvent _penDown = PointerDownEvent(
  kind: PointerDeviceKind.stylus,
  pressure: 0.3,
  pressureMin: 0,
  pressureMax: 1,
);

Future<void> _push(Object? value, {String method = 'pressure'}) {
  return TrackpadPressure.instance.handleMethodCall(MethodCall(method, value));
}

void main() {
  tearDown(() {
    TrackpadPressure.instance.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  group('TrackpadPressure.handleMethodCall', () {
    test('shapes the held pressure with the trackpad curve', () async {
      await _push(0.25);
      expect(
        TrackpadPressure.instance.pressure,
        closeTo(pow(0.25, AppInteraction.trackpadPressureCurveExponent), 1e-9),
      );
    });

    test('clamps out-of-range values', () async {
      await _push(3);
      expect(TrackpadPressure.instance.pressure, 1);
      await _push(-1);
      expect(TrackpadPressure.instance.pressure, 0);
    });

    test('a null update releases the pressure', () async {
      await _push(0.5);
      await _push(null);
      expect(TrackpadPressure.instance.pressure, isNull);
    });

    test('ignores unknown methods', () async {
      await _push(0.5, method: 'other');
      expect(TrackpadPressure.instance.pressure, isNull);
    });
  });

  test('listen is a no-op off macOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(TrackpadPressure.isSupported, isFalse);
    TrackpadPressure.instance.listen();
  });

  test('listen routes the runner channel on macOS', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    TrackpadPressure.instance.listen();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'com.vteam.fpaint/trackpad',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('pressure', 1.0)),
      (ByteData? _) {},
    );

    expect(TrackpadPressure.instance.pressure, 1);
  });

  group('brushPointerPressure', () {
    test('uses the trackpad pressure for a mouse pointer on macOS when enabled', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await _push(1.0);
      expect(usesTrackpadPressure(_mouseDown, enabled: true), isTrue);
      expect(brushPointerPressure(_mouseDown, trackpadPressureEnabled: true), 1);
    });

    test('ignores the trackpad when the setting is off', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await _push(1.0);
      expect(usesTrackpadPressure(_mouseDown, enabled: false), isFalse);
      expect(brushPointerPressure(_mouseDown, trackpadPressureEnabled: false), isNull);
    });

    test('ignores the trackpad off macOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await _push(1.0);
      expect(brushPointerPressure(_mouseDown, trackpadPressureEnabled: true), isNull);
    });

    test('a pen keeps its own pressure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await _push(1.0);
      expect(usesTrackpadPressure(_penDown, enabled: true), isFalse);
      expect(brushPointerPressure(_penDown, trackpadPressureEnabled: true), closeTo(0.3, 1e-9));
    });
  });
}
