import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_harness.dart';

/// Where on the canvas widget the stroke starts.
const Offset _strokeStart = Offset(200, 200);

/// One leg of the stroke, comfortably past the sample spacing.
const Offset _strokeStep = Offset(40, 0);

/// Brush size used while painting the selection.
const double _brushSize = 30;

void main() {
  late AppProvider appProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppPreferences preferences = AppPreferences();
    await preferences.getPref();
    appProvider = AppProvider(preferences: preferences);
    preferences.setBrushSize(_brushSize);
  });

  testWidgets('dragging with the selection brush selects the painted band without drawing', (
    WidgetTester tester,
  ) async {
    appProvider.activateSelectorMode(SelectorMode.brush);
    await tester.pumpWidget(
      InheritedControllerScope<AppPreferences>(
        controller: appProvider.preferences,
        child: InheritedControllerScope<AppProvider>(
          controller: appProvider,
          child: InheritedControllerScope<LayersProvider>(
            controller: appProvider.layers,
            child: InheritedControllerScope<ShellProvider>(
              controller: ShellProvider(),
              child: buildLocalizedTestApp(
                home: const Scaffold(body: SizedBox.expand(child: MainView())),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final Offset origin = tester.getTopLeft(find.byType(CanvasGestureHandler));

    final TestGesture gesture = await tester.startGesture(origin + _strokeStart, kind: PointerDeviceKind.mouse);
    await gesture.moveBy(_strokeStep);
    await gesture.moveBy(_strokeStep);
    await gesture.up();
    await tester.pump();

    final SelectorModel selection = appProvider.selectorModel;
    final Offset middle = appProvider.toCanvas(_strokeStart + _strokeStep);
    final Offset farAbove = appProvider.toCanvas(_strokeStart + _strokeStep - const Offset(0, _brushSize * 2));
    expect(selection.isVisible, isTrue);
    expect(selection.path1!.contains(middle), isTrue);
    expect(selection.path1!.contains(farAbove), isFalse);
    expect(appProvider.selectedTool, ToolKind.selector);
    expect(appProvider.layers.selectedLayer.lastUserAction, isNull, reason: 'Selecting must not paint.');

    // Let the size ring that rode along the stroke fade out and the layer
    // thumbnail refresh queued on release run.
    await tester.pump(AppDefaults.brushSizePreviewDuration);
    await tester.pump(AppDefaults.thumbnailDebounceDuration);
  });
}
