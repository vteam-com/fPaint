import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_snackbar.dart';

/// Returns whether the selected layer of [appProvider] may be edited.
///
/// When the layer is locked, shows the localized "layer locked" snackbar on
/// [context] and returns `false`, so callers can write
/// `if (!guardSelectedLayerUnlocked(context, appProvider)) return;`.
bool guardSelectedLayerUnlocked(BuildContext context, AppProvider appProvider) {
  if (!appProvider.isSelectedLayerLocked) {
    return true;
  }
  context.showSnackBarMessage(
    context.l10n.layerLockedForEditing(appProvider.layers.selectedLayer.name),
  );
  return false;
}
