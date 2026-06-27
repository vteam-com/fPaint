import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/version.dart';
import 'package:fpaint/panels/side_panel/attribution_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays an about dialog with information about the application.
///
/// This function shows a dialog box that includes the application's name,
/// version, legal information, and an icon. It also displays the device's
/// screen resolution and a link to the application's GitHub repository.
///
/// The [context] parameter is the [BuildContext] used to show the dialog.
void showAboutBox(final BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final String screenResolution = '${mediaQuery.size.width.toInt()} x ${mediaQuery.size.height.toInt()}';

  showAppDialog<void>(
    context: context,
    builder: (final BuildContext dialogContext) {
      return AppDialog(
        title: '$appName $packageVersion',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Image.asset(
              'assets/app_icon.png',
              width: AppLayout.appIconSize,
              height: AppLayout.appIconSize,
            ),
            const SizedBox(height: AppSpacing.medium),
            const AppText(AppConfig.applicationCopyright),
            const SizedBox(height: AppSpacing.large),
            AppText(l10n.deviceScreenResolution(screenResolution)),
          ],
        ),
        actions: <Widget>[
          AppRowSecondaryButton(
            onPressed: () => launchUrl(Uri.parse(AppConfig.repositoryUrl)),
            text: l10n.githubRepo,
          ),
          AppRowSecondaryButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await showAttributionDialog(context);
            },
            text: l10n.flutterAttribution,
          ),
          AppRowPrimaryButton(
            onPressed: () => Navigator.pop(dialogContext),
            text: l10n.close,
          ),
        ],
      );
    },
  );
}
