import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/effect_brush_model.dart';
import 'package:fpaint/models/selection_effect.dart';

void main() {
  group('EffectBrushModel', () {
    test('is armed only when paint mode and an effect are both set', () {
      final EffectBrushModel model = EffectBrushModel();
      expect(model.isArmed, isFalse);

      model.paintMode = true;
      expect(model.isArmed, isFalse);

      model.arm(SelectionEffect.blur);
      expect(model.isArmed, isTrue);
      expect(model.effect, SelectionEffect.blur);
      expect(model.size, SelectionEffect.blur.defaultSize);
    });

    test('disarm clears the effect but keeps paint mode', () {
      final EffectBrushModel model = EffectBrushModel()
        ..paintMode = true
        ..arm(SelectionEffect.hueSaturation);

      model.disarm();

      expect(model.effect, isNull);
      expect(model.isArmed, isFalse);
      expect(model.paintMode, isTrue);
    });
  });
}
