import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Method the native side calls to ask whether the app may terminate.
const String quitRequestedMethod = 'quitRequested';

/// Decides whether a quit request may proceed, prompting when work is unsaved.
///
/// The native side defers termination until this resolves, so a `true` result
/// lets the app close and `false` cancels the quit. When no context is
/// available there is no way to ask, so the quit is allowed through rather
/// than trapping the user in an app that refuses to close.
///
/// - Parameters:
///   - layers: The document whose unsaved state gates the prompt.
///   - context: The [BuildContext] used to display the confirmation dialog.
Future<bool> confirmQuitWithUnsavedChanges({
  required LayersProvider layers,
  required BuildContext? context,
}) async {
  if (layers.hasChanged == false) {
    return true;
  }

  if (context == null || context.mounted == false) {
    return true;
  }

  final AppLocalizations l10n = context.l10n;
  final bool? shouldQuit = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialog(
        title: l10n.unsavedChanges,
        content: AppText(l10n.unsavedChangesQuitPrompt),
        actions: <Widget>[
          AppRowSecondaryButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            text: l10n.cancel,
          ),
          AppRowDangerButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            text: l10n.quitWithoutSaving,
          ),
        ],
      );
    },
  );

  return shouldQuit == true;
}
