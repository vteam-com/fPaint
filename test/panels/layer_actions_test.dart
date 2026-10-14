import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_en.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/layer_actions.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final AppLocalizations l10n = AppLocalizationsEn();
  late LayerProvider layer;

  setUp(() {
    layer = LayerProvider(
      name: 'Layer',
      size: const Size(10, 10),
      onThumbnailChanged: () {},
    );
  });

  test('only delete, merge and blend need a removable layer', () {
    expect(
      LayerAction.values.where((LayerAction action) => action.requiresRemovableLayer),
      <LayerAction>[LayerAction.delete, LayerAction.mergeBelow, LayerAction.blendMode],
    );
  });

  test('every action has an icon and a label', () {
    for (final LayerAction action in LayerAction.values) {
      expect(action.icon(layer), isA<AppIcon>());
      expect(action.label(l10n, layer), isNotEmpty);
    }
  });

  test('lock reflects the layer lock state', () {
    expect(LayerAction.lock.icon(layer), AppIcon.lockOpen);
    expect(LayerAction.lock.iconColor(layer), isNull);
    expect(LayerAction.lock.label(l10n, layer), l10n.layerLockEdits);

    layer.isLocked = true;
    expect(LayerAction.lock.icon(layer), AppIcon.lock);
    expect(LayerAction.lock.iconColor(layer), AppColors.layerHiddenWarning);
    expect(LayerAction.lock.label(l10n, layer), l10n.layerUnlockEdits);
  });

  test('visibility reflects the layer visibility', () {
    expect(LayerAction.visibility.icon(layer), AppIcon.visibility);
    expect(LayerAction.visibility.iconColor(layer), AppColors.primary);
    expect(LayerAction.visibility.label(l10n, layer), l10n.layerHide);

    layer.isVisible = false;
    expect(LayerAction.visibility.icon(layer), AppIcon.visibilityOff);
    expect(LayerAction.visibility.iconColor(layer), AppColors.layerHiddenWarning);
    expect(LayerAction.visibility.label(l10n, layer), l10n.layerShow);
  });

  test('stateless actions have no tint', () {
    expect(LayerAction.rename.iconColor(layer), isNull);
  });
}
