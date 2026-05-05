import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = AppPreferences();
    await preferences.getPref();
  });

  group('defaults', () {
    test('isLoaded is true after getPref', () {
      expect(preferences.isLoaded, isTrue);
    });

    test('brushSize has default value', () {
      expect(preferences.brushSize, AppDefaults.brushSize);
    });

    test('brushColor defaults to black', () {
      expect(preferences.brushColor, AppColors.black);
    });

    test('fillColor defaults to blue', () {
      expect(preferences.fillColor, AppColors.blue);
    });

    test('useApplePencil defaults to AppDefaults value', () {
      expect(preferences.useApplePencil, AppDefaults.useApplePencil);
    });

    test('languageCode defaults to null', () {
      expect(preferences.languageCode, isNull);
    });

    test('preferredLocale defaults to null', () {
      expect(preferences.preferredLocale, isNull);
    });

    test('sidePanelDistance has default value', () {
      expect(preferences.sidePanelDistance, AppLayout.sidePanelTopDefault);
    });
  });

  group('setBrushSize', () {
    test('updates brushSize', () async {
      await preferences.setBrushSize(15.0);
      expect(preferences.brushSize, 15.0);
    });

    test('persists to SharedPreferences', () async {
      await preferences.setBrushSize(20.0);
      final SharedPreferences prefs = await preferences.getPref();
      expect(prefs.getDouble(AppPreferences.keyBrushSize), 20.0);
    });
  });

  group('setBrushColor', () {
    test('updates brushColor', () async {
      await preferences.setBrushColor(const Color(0xFFFF0000));
      expect(preferences.brushColor, const Color(0xFFFF0000));
    });

    test('persists to SharedPreferences', () async {
      const Color red = Color(0xFFFF0000);
      await preferences.setBrushColor(red);
      final SharedPreferences prefs = await preferences.getPref();
      expect(prefs.getInt(AppPreferences.keyLastBrushColor), red.toARGB32());
    });
  });

  group('setFillColor', () {
    test('updates fillColor', () async {
      await preferences.setFillColor(const Color(0xFF00FF00));
      expect(preferences.fillColor, const Color(0xFF00FF00));
    });

    test('persists to SharedPreferences', () async {
      const Color green = Color(0xFF00FF00);
      await preferences.setFillColor(green);
      final SharedPreferences prefs = await preferences.getPref();
      expect(prefs.getInt(AppPreferences.keyLastFillColor), green.toARGB32());
    });
  });

  group('setUseApplePencil', () {
    test('updates useApplePencil', () async {
      await preferences.setUseApplePencil(false);
      expect(preferences.useApplePencil, isFalse);
    });

    test('notifies listeners', () async {
      int notifyCount = 0;
      preferences.addListener(() => notifyCount++);
      await preferences.setUseApplePencil(false);
      expect(notifyCount, 1);
    });

    test('persists to SharedPreferences', () async {
      await preferences.setUseApplePencil(false);
      final SharedPreferences prefs = await preferences.getPref();
      expect(prefs.getBool(AppPreferences.keyUseApplePencil), isFalse);
    });
  });

  group('setLanguageCode', () {
    test('updates languageCode', () async {
      await preferences.setLanguageCode('fr');
      expect(preferences.languageCode, 'fr');
    });

    test('setting to null clears languageCode', () async {
      await preferences.setLanguageCode('es');
      await preferences.setLanguageCode(null);
      expect(preferences.languageCode, isNull);
    });

    test('preferredLocale reflects languageCode', () async {
      await preferences.setLanguageCode('es');
      expect(preferences.preferredLocale, const Locale('es'));
    });

    test('preferredLocale is null when languageCode is null', () async {
      await preferences.setLanguageCode(null);
      expect(preferences.preferredLocale, isNull);
    });

    test('notifies listeners', () async {
      int notifyCount = 0;
      preferences.addListener(() => notifyCount++);
      await preferences.setLanguageCode('fr');
      expect(notifyCount, 1);
    });
  });

  group('setSidePanelDistance', () {
    test('updates sidePanelDistance', () async {
      await preferences.setSidePanelDistance(250.0);
      expect(preferences.sidePanelDistance, 250.0);
    });

    test('persists to SharedPreferences', () async {
      await preferences.setSidePanelDistance(300.0);
      final SharedPreferences prefs = await preferences.getPref();
      expect(prefs.getDouble(AppPreferences.keySidePanelDistance), 300.0);
    });
  });

  group('recoveryDraftSourceFilePath', () {
    test('returns null when not set', () async {
      final String? path = await preferences.getRecoveryDraftSourceFilePath();
      expect(path, isNull);
    });

    test('set and get round-trip', () async {
      await preferences.setRecoveryDraftSourceFilePath('/tmp/test.ora');
      final String? path = await preferences.getRecoveryDraftSourceFilePath();
      expect(path, '/tmp/test.ora');
    });

    test('setting null clears the path', () async {
      await preferences.setRecoveryDraftSourceFilePath('/tmp/test.ora');
      await preferences.setRecoveryDraftSourceFilePath(null);
      final String? path = await preferences.getRecoveryDraftSourceFilePath();
      expect(path, isNull);
    });

    test('setting empty clears the path', () async {
      await preferences.setRecoveryDraftSourceFilePath('/tmp/test.ora');
      await preferences.setRecoveryDraftSourceFilePath('');
      final String? path = await preferences.getRecoveryDraftSourceFilePath();
      expect(path, isNull);
    });

    test('clearRecoveryDraftSourceFilePath clears value', () async {
      await preferences.setRecoveryDraftSourceFilePath('/tmp/test.ora');
      await preferences.clearRecoveryDraftSourceFilePath();
      final String? path = await preferences.getRecoveryDraftSourceFilePath();
      expect(path, isNull);
    });
  });

  group('loading from persisted values', () {
    test('loads saved brushSize on re-init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyBrushSize: 42.0,
      });
      final AppPreferences prefs2 = AppPreferences();
      await prefs2.getPref();
      expect(prefs2.brushSize, 42.0);
    });

    test('loads saved languageCode on re-init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyLanguageCode: 'es',
      });
      final AppPreferences prefs2 = AppPreferences();
      await prefs2.getPref();
      expect(prefs2.languageCode, 'es');
      expect(prefs2.preferredLocale, const Locale('es'));
    });

    test('loads saved useApplePencil on re-init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyUseApplePencil: false,
      });
      final AppPreferences prefs2 = AppPreferences();
      await prefs2.getPref();
      expect(prefs2.useApplePencil, isFalse);
    });

    test('loads saved recentFiles on re-init', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPreferences.keyRecentFiles: <String>['/tmp/a.png', '/tmp/b.ora'],
      });
      final AppPreferences prefs2 = AppPreferences();
      await prefs2.getPref();
      expect(prefs2.recentFiles, <String>['/tmp/a.png', '/tmp/b.ora']);
    });
  });

  group('recentFiles', () {
    test('defaults to empty list', () {
      expect(preferences.recentFiles, isEmpty);
    });

    test('addRecentFile adds a path', () async {
      await preferences.addRecentFile('/tmp/test.png');
      expect(preferences.recentFiles, <String>['/tmp/test.png']);
    });

    test('addRecentFile moves duplicate to front', () async {
      await preferences.addRecentFile('/tmp/a.png');
      await preferences.addRecentFile('/tmp/b.png');
      await preferences.addRecentFile('/tmp/a.png');
      expect(preferences.recentFiles, <String>['/tmp/a.png', '/tmp/b.png']);
    });

    test('addRecentFile caps at maxRecentFiles', () async {
      for (int i = 0; i < AppLimits.maxRecentFiles + 5; i++) {
        await preferences.addRecentFile('/tmp/file_$i.png');
      }
      expect(preferences.recentFiles.length, AppLimits.maxRecentFiles);
      // Most recent should be first
      expect(
        preferences.recentFiles.first,
        '/tmp/file_${AppLimits.maxRecentFiles + 4}.png',
      );
    });

    test('addRecentFile persists to SharedPreferences', () async {
      await preferences.addRecentFile('/tmp/test.png');
      final SharedPreferences prefs = await preferences.getPref();
      expect(
        prefs.getStringList(AppPreferences.keyRecentFiles),
        <String>['/tmp/test.png'],
      );
    });

    test('addRecentFile notifies listeners', () async {
      int notifyCount = 0;
      preferences.addListener(() => notifyCount++);
      await preferences.addRecentFile('/tmp/test.png');
      expect(notifyCount, 1);
    });

    test('recentFiles list is unmodifiable', () {
      expect(
        () => preferences.recentFiles.add('/tmp/hack.png'),
        throwsUnsupportedError,
      );
    });
  });
}
