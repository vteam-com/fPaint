import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Asks the user whether they want to discard their current unsaved work.
///
/// Returns `true` when the user chose to discard, `false` otherwise.
///
/// - Parameters:
///   - context: The [BuildContext] used to display the dialog.
Future<bool> confirmDiscardCurrentWork(BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  final bool? discardCurrentFile = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AppDialog(
        title: l10n.discardCurrentDocumentQuestion,
        actions: <Widget>[
          AppRowDangerButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            text: l10n.discard,
          ),
          AppRowSecondaryButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            text: l10n.no,
          ),
        ],
      );
    },
  );

  return discardCurrentFile == true;
}

/// Returns whether the caller may replace the current document.
///
/// Proceeds straight away when [layers] has no unsaved changes; otherwise asks
/// via [confirmDiscardCurrentWork] and returns the user's answer.
Future<bool> confirmDiscardIfChanged(
  BuildContext context,
  LayersProvider layers,
) async {
  return !layers.hasChanged || await confirmDiscardCurrentWork(context);
}
