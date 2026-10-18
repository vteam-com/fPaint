import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/main.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/canvas_gesture_handler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/painting_test_helpers.dart';
import '../helpers/showcase_painting_helpers.dart';

const String _languageCode = 'en';
const Color _fillColor = Color(0xFF2A1C18);
const int _tapPointer = 1;

void main() {
  SharedPreferences.setMockInitialValues(<String, Object>{AppPreferences.keyLanguageCode: _languageCode});

  testWidgets('a quick paint-bucket tap fills once and leaves no preview or pointer lock behind', (
    WidgetTester tester,
  ) async {
    configureTestViewport(tester);
    await tester.pumpWidget(MyApp());
    await pumpForUnitTestUiSettle(tester);

    final AppProvider appProvider = appProviderFromTester(tester);
    await tapByKey(tester, Keys.toolFill);
    await tapByKey(tester, Keys.toolFillModeSolid);
    appProvider.fillColor = _fillColor;
    expect(appProvider.selectedTool, ToolKind.fill);

    final LayerProvider layer = appProvider.layers.selectedLayer;
    final int actionsBefore = layer.actionStack.length;

    // Down and up dispatched synchronously, back to back — how one input
    // packet delivers a quick tap (e.g. trackpad tap-to-click). The release is
    // handled while the press is still suspended in its async selection check.
    final Offset canvasCenter = tester.getCenter(find.byType(CanvasGestureHandler));
    tester.binding.handlePointerEvent(
      PointerDownEvent(pointer: _tapPointer, position: canvasCenter, buttons: kPrimaryButton),
    );
    tester.binding.handlePointerEvent(PointerUpEvent(pointer: _tapPointer, position: canvasCenter));

    final bool filled = await pumpUntilIdle(tester, () => layer.actionStack.length > actionsBefore);
    expect(filled, isTrue, reason: 'The tap should still fill');
    await tester.pump();

    expect(layer.actionStack.length, actionsBefore + 1, reason: 'Exactly one fill should be committed');
    expect(appProvider.fillPreviewAction, isNull, reason: 'No preview may be left drawn over the canvas');
    expect(appProvider.tolerancePointerAnchor, isNull, reason: 'The tolerance pointer lock must be released');

    appProvider.undoAction();
    await tester.pump();
    expect(layer.actionStack.length, actionsBefore);
    expect(appProvider.fillPreviewAction, isNull, reason: 'Undo must not reveal a ghost fill');

    await tester.pump(AppDefaults.thumbnailDebounceDuration);
  });
}
