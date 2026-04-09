import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const String _platformWindows = 'Windows';
const String _platformAndroid = 'Android';
const String _platformLinux = 'Linux';

/// A page that displays the available platforms for the application.
class PlatformsPage extends StatelessWidget {
  const PlatformsPage({super.key});

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.availablePlatforms)),
      body: Center(
        child: SizedBox(
          width: AppLayout.platformPageWidth,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                platformItem(
                  'macOS',
                  'assets/images/platforms/platformDesktopMacOS.png',
                  l10n.desktopSoftware,
                  'https://paint.vteam.com/downloads/flutter-macos-app.zip',
                ),
                platformItem(
                  _platformWindows,
                  'assets/images/platforms/platformDesktopWindows.png',
                  l10n.desktopSoftware,
                  'https://paint.vteam.com/downloads/flutter-windows-app.zip',
                ),
                platformItem(
                  _platformLinux,
                  'assets/images/platforms/platformDesktopLinux.png',
                  l10n.desktopSoftware,
                  'https://paint.vteam.com/downloads/flutter-linux-app.zip',
                ),
                const SizedBox(
                  height: AppSpacing.huge,
                ),
                platformItem(
                  'iOS',
                  'assets/images/platforms/platformMobileIOS.png',
                  l10n.mobileApp,
                  'https://apps.apple.com/us/app/cooking-timer-by-vteam/id1188460815',
                ),
                platformItem(
                  _platformAndroid,
                  'assets/images/platforms/platformMobileAndroid.png',
                  l10n.mobileApp,
                  'https://play.google.com/store/apps/details?id=com.vteam.cookingtimerflutter',
                ),
                const SizedBox(
                  height: AppSpacing.huge,
                ),
                platformItem(
                  l10n.webBrowser,
                  'assets/images/platforms/platformWeb.png',
                  l10n.runOnMostBrowsers,
                  'https://paint.vteam.com',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A widget that displays a platform item with an image, name, description, and URL.
  Widget platformItem(
    final String name,
    final String image,
    final String description,
    final String url,
  ) {
    return Card(
      elevation: AppMath.pair.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xl),
      child: InkWell(
        onTap: () {
          launchUrl(Uri.parse(url));
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            spacing: AppSpacing.xxl,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Colors.white,
                foregroundImage: AssetImage(image),
              ),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: AppLayout.platformTitleFontSize)),
              ),
              Expanded(
                child: Opacity(
                  opacity: AppVisual.disabled,
                  child: Text(description),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
