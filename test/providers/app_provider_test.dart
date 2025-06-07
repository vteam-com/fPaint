import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/user_action_drawing.dart'; // For ActionType, BrushStyle
import 'package:fpaint/models/selector_model.dart';    // For SelectorMode
import 'package:fpaint/models/fill_model.dart';        // For FillMode
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_preferences.dart'; // To know default values and PREFERENCE KEYS
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for SharedPreferences
@GenerateMocks([SharedPreferences])
import 'app_provider_test.mocks.dart';

// Keys from AppPreferences (copied for test visibility)
const String keyBrushSize = 'keyBrushSize';
const String keyLastBrushColor = 'keyLastBrushColor';
const String keyLastFillColor = 'keyLastFillColor';
// const String keySelectedAction = 'selectedAction'; // This key was assumed, but not in AppPreferences

void main() {
  late AppProvider appProvider;
  late MockSharedPreferences mockSharedPreferences;

  // Helper to setup AppProvider with mocked SharedPreferences for AppPreferences
  Future<AppProvider> setupAppProviderWithMockPrefs(Map<String, Object> initialMockValues) async {
    SharedPreferences.setMockInitialValues(initialMockValues);
    final newAppProvider = AppProvider();
    // AppProvider constructor calls preferences.getPref() which loads from SharedPreferences.getInstance()
    // Ensure this async operation completes before returning the provider.
    await newAppProvider.preferences.getPref();
    return newAppProvider;
  }

  setUp(() async {
    // This global mock is for any direct SharedPreferences.getInstance() calls
    // if not already scoped by setMockInitialValues per test/group.
    mockSharedPreferences = MockSharedPreferences();
    SharedPreferences.setMockInitialValues({}); // Default to empty for most tests in setUp

    appProvider = AppProvider();
    await appProvider.preferences.getPref(); // Ensure default loading path in constructor completes
  });

  group('AppProvider Initialization and Defaults from AppPreferences', () {
    test('Initial selectedAction is brush (AppProvider internal default)', () {
      // AppProvider initializes _selectedAction = ActionType.brush directly
      expect(appProvider.selectedAction, ActionType.brush);
    });

    test('Initial brushColor is AppPreferences default (Colors.black)', () {
      expect(appProvider.brushColor, Colors.black);
    });

    test('Initial fillColor is AppPreferences default (Colors.blue)', () {
      expect(appProvider.fillColor.value, Colors.blue.value);
    });

    test('Initial brush size is AppPreferences default (5.0)', () {
      expect(appProvider.brushSize, 5.0);
    });

    test('Initial selector mode is rectangle (SelectorModel default)', () {
      expect(appProvider.selectorModel.mode, SelectorMode.rectangle);
    });
  });

  group('Tool Management (selectedAction)', () {
    test('selectedAction setter updates selectedAction (in-memory)', () {
      appProvider.selectedAction = ActionType.eraser;
      expect(appProvider.selectedAction, ActionType.eraser);
      // Note: selectedAction is NOT persisted by AppPreferences in the current codebase.
      // So, no verify(mockSharedPreferences.setInt(...)) for selectedAction.
    });
  });

  group('Color Management (via AppPreferences)', () {
    test('brushColor setter updates brushColor', () {
      appProvider.brushColor = Colors.red;
      expect(appProvider.brushColor, Colors.red);
    });

    test('fillColor setter updates fillColor', () {
      appProvider.fillColor = Colors.green;
      expect(appProvider.fillColor, Colors.green);
    });
  });

  group('Brush Properties (via AppPreferences)', () {
    test('brushSize setter updates brushSize', () {
      appProvider.brushSize = 20.0;
      expect(appProvider.brushSize, 20.0);
    });
  });

  group('Selector Properties (AppProvider.selectorModel direct manipulation)', () {
    test('selectorModel.mode can be updated', () {
      appProvider.selectorModel.mode = SelectorMode.lasso;
      expect(appProvider.selectorModel.mode, SelectorMode.lasso);
      // This is an in-memory change to a model owned by AppProvider. No direct prefs save here.
    });
  });

  group('Preferences Loading (Testing AppProvider reaction to AppPreferences)', () {
    test('AppProvider reflects values loaded by AppPreferences', () async {
      final initialPrefs = {
        keyLastBrushColor: Colors.purple.value,
        keyLastFillColor: Colors.orange.value,
        keyBrushSize: 15.0,
      };
      // Setup global SharedPreferences mock that AppPreferences will use
      SharedPreferences.setMockInitialValues(Map<String, Object>.fromEntries(
        initialPrefs.entries.map((e) => MapEntry(e.key, e.value as Object))
      ));

      final newAppProvider = AppProvider();
      await newAppProvider.preferences.getPref(); // Ensure AppPreferences loads these values

      expect(newAppProvider.brushColor.value, Colors.purple.value);
      expect(newAppProvider.fillColor.value, Colors.orange.value);
      expect(newAppProvider.brushSize, 15.0);
    });

    test('AppProvider uses default values from AppPreferences if SharedPreferences is empty for those keys', () async {
      SharedPreferences.setMockInitialValues({}); // Empty prefs

      final defaultBackedPrefs = AppPreferences(); // Vanilla instance to compare defaults
      await defaultBackedPrefs.getPref(); // Loads its internal defaults
                                          // because SharedPreferences is empty.

      final newAppProvider = AppProvider();
      await newAppProvider.preferences.getPref(); // Should also load its defaults

      expect(newAppProvider.brushColor, defaultBackedPrefs.brushColor); // e.g. Colors.black
      expect(newAppProvider.fillColor, defaultBackedPrefs.fillColor);   // e.g. Colors.blue
      expect(newAppProvider.brushSize, defaultBackedPrefs.brushSize);   // e.g. 5.0
    });
  });

  // Placeholder for canvas operation tests
  group('Canvas Operations', () {
    test('canvasClear resets layers and view', () {
      // Add a layer or change scale/offset first
      appProvider.layers.addTop(name: "Test Layer"); // Use a valid method to add a layer
      appProvider.canvasOffset = const Offset(100, 100);
      appProvider.layers.scale = 2.0;

      appProvider.canvasClear(const Size(300, 300));

      expect(appProvider.layers.length, 1); // Should have one default (white background) layer
      expect(appProvider.layers.selectedLayerIndex, 0);
      expect(appProvider.canvasOffset, Offset.zero);
      expect(appProvider.layers.scale, 1.0);
      expect(appProvider.layers.size, const Size(300, 300));
    });

    test('toCanvas and fromCanvas coordinate conversion', () {
      appProvider.canvasOffset = const Offset(10, 20);
      appProvider.layers.scale = 2.0;

      const screenPoint = Offset(50, 80);
      // canvasX = (50 - 10) / 2 = 20
      // canvasY = (80 - 20) / 2 = 30
      final canvasPoint = appProvider.toCanvas(screenPoint);
      expect(canvasPoint, const Offset(20, 30));

      final convertedScreenPoint = appProvider.fromCanvas(canvasPoint);
      expect(convertedScreenPoint.dx, closeTo(screenPoint.dx, 0.01));
      expect(convertedScreenPoint.dy, closeTo(screenPoint.dy, 0.01));
    });
  });

  // TODO: Tests for other AppProvider methods:
  // applyScaleToCanvas, regionErase, regionCut, regionCopy, paste,
  // recordExecuteDrawingActionToSelectedLayer, undoAction, redoAction,
  // canvasPan, canvasFitToContainer,
  // selector operations (selectorCreationStart, etc.), crop, newDocumentFromClipboardImage
}
