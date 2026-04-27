import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _repoUrl = 'https://github.com/vteam-com/fPaint';
const String _applicationLegalese = '(c) 2025 VTeam';

/// Displays an about dialog with information about the application.
///
/// This function shows a dialog box that includes the application's name,
/// version, legal information, and an icon. It also displays the device's
/// screen resolution and a link to the application's GitHub repository.
///
/// The [context] parameter is the [BuildContext] used to show the dialog.
Future<void> showAboutBox(final BuildContext context) async {
  final AppLocalizations l10n = context.l10n;
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final String screenResolution = '${mediaQuery.size.width.toInt()} x ${mediaQuery.size.height.toInt()}';
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();

  if (!context.mounted) {
    return;
  }

  showAppDialog<void>(
    context: context,
    builder: (final BuildContext dialogContext) {
      return AppDialog(
        title: '$appName ${packageInfo.version}',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Image.asset(
              'assets/app_icon.png',
              width: AppLayout.appIconSize,
              height: AppLayout.appIconSize,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppText(_applicationLegalese),
            const SizedBox(height: AppSpacing.xxl),
            AppText(l10n.deviceScreenResolution(screenResolution)),
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(_repoUrl)),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AppText(
                  l10n.githubRepo,
                  variant: AppTextVariant.button,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          AppButtonText(
            onPressed: () => Navigator.pop(dialogContext),
            text: l10n.cancel,
          ),
        ],
      );
    },
  );
}
