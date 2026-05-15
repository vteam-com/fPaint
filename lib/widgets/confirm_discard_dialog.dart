import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Asks the user whether they want to discard their current unsaved work.
///
/// Returns `true` when the user chose to discard, `false` otherwise.
///
/// - Parameters:
///   - context: The [BuildContext] used to display the dialog.
Future<bool> confirmDiscardCurrentWork(final BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  final bool? discardCurrentFile = await showAppDialog<bool>(
    context: context,
    builder: (final BuildContext context) {
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
