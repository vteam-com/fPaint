import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/my_window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MyWindowManager.getSafeDouble', () {
    test('returns stored double value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'window_x': 123.5,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(MyWindowManager.getSafeDouble(prefs, 'window_x'), 123.5);
    });

    test('converts stored int value to double', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'window_width': 800,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(MyWindowManager.getSafeDouble(prefs, 'window_width'), 800.0);
    });

    test('returns null for missing or unsupported value type', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'window_bad': 'oops',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(MyWindowManager.getSafeDouble(prefs, 'window_bad'), isNull);
      expect(MyWindowManager.getSafeDouble(prefs, 'missing_key'), isNull);
    });
  });
}
