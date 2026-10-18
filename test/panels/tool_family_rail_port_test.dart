import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';
import 'package:fpaint/panels/tools/tool_family_rail.dart';
import 'package:fpaint/providers/tool_rail_port.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/painting_test_helpers.dart';
import '../helpers/widget_test_harness.dart';

const double _fakeBrushSize = 12;
const double _fakeStrength = 0.5;

/// A tool rail state with no app provider behind it.
class _FakeRail implements ToolRailPort {
  @override
  final ChangeNotifier railChanges = ChangeNotifier();

  @override
  ToolKind selectedTool = ToolKind.brush;

  @override
  SelectionEffect? armedEffect;

  @override
  double brushSize = _fakeBrushSize;

  @override
  double effectStrength = _fakeStrength;

  final List<ToolDescriptor> activated = <ToolDescriptor>[];

  @override
  ToolDescriptor get activeTool =>
      armedEffect != null ? ToolDescriptor.adjust(armedEffect) : ToolDescriptor.gesture(selectedTool);

  @override
  void activateTool(ToolDescriptor tool) {
    activated.add(tool);
    selectedTool = tool.tool ?? selectedTool;
    railChanges.notifyListeners();
  }

  @override
  void armEffectBrush(SelectionEffect effect) {
    armedEffect = effect;
    railChanges.notifyListeners();
  }

  @override
  void disarmEffectBrush() {
    armedEffect = null;
    railChanges.notifyListeners();
  }

  @override
  void setEffectStrength(double value) => effectStrength = value;
}

void main() {
  late _FakeRail rail;

  setUp(() => rail = _FakeRail());

  Future<void> pumpRail(WidgetTester tester) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ToolFamilyRail(minimal: false, port: rail)),
        ),
      ),
    );
  }

  testWidgets('tapping a gesture tool activates it through the port', (WidgetTester tester) async {
    await pumpRail(tester);

    await tapByKey(tester, Keys.toolSmudge);

    expect(rail.activated, <ToolDescriptor>[const ToolDescriptor.gesture(ToolKind.smudge)]);
    expect(rail.selectedTool, ToolKind.smudge);
  });

  testWidgets('an effect arms on the first tap, shows its controls, and disarms on the second', (
    WidgetTester tester,
  ) async {
    const SelectionEffect effect = SelectionEffect.blur;
    await pumpRail(tester);

    await tapByKey(tester, const ValueKey<SelectionEffect>(effect));
    expect(rail.armedEffect, effect);
    expect(find.byKey(Keys.effectPaintStrengthSlider), findsOneWidget);

    await tapByKey(tester, const ValueKey<SelectionEffect>(effect));
    expect(rail.armedEffect, isNull);
    expect(find.byKey(Keys.effectPaintStrengthSlider), findsNothing);
  });
}
