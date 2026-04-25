import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

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
        title: Text(l10n.discardCurrentDocumentQuestion),
        actions: <Widget>[
          AppTextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(l10n.discard),
          ),
          AppTextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(l10n.no),
          ),
        ],
      );
    },
  );

  return discardCurrentFile == true;
}
