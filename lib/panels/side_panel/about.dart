import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _repoUrl = 'https://github.com/your-repo-url';
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

  showAboutDialog(
    context: context,
    applicationName: appName,
    applicationVersion: packageInfo.version,
    applicationLegalese: _applicationLegalese,
    applicationIcon: Image.asset(
      'assets/app_icon.png',
      width: AppLayout.appIconSize,
      height: AppLayout.appIconSize,
    ),
    children: <Widget>[
      const SizedBox(height: AppSpacing.xxl),
      Text(l10n.deviceScreenResolution(screenResolution)),
      const SizedBox(height: AppSpacing.xxl),
      InkWell(
        child: Text(
          l10n.githubRepo,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
        onTap: () => launchUrl(Uri.parse(_repoUrl)),
      ),
    ],
  );
}
