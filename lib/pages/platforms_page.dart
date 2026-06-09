import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:url_launcher/url_launcher.dart';

const String _platformWindows = 'Windows';
const String _platformAndroid = 'Android';
const String _platformLinux = 'Linux';
const String _platformMacOS = 'macOS';
const String _platformIOS = 'iOS';

const String _urlMacOSDownload = 'https://paint.vteam.com/downloads/flutter-macos-app.zip';
const String _urlWindowsDownload = 'https://paint.vteam.com/downloads/flutter-windows-app.zip';
const String _urlLinuxDownload = 'https://paint.vteam.com/downloads/flutter-linux-app.zip';
const String _urlIOSApp = 'https://apps.apple.com/us/app/cooking-timer-by-vteam/id1188460815';
const String _urlAndroidApp = 'https://play.google.com/store/apps/details?id=com.vteam.cookingtimerflutter';
const String _urlWebApp = 'https://paint.vteam.com';

/// A page that displays the available platforms for the application.
class PlatformsPage extends StatelessWidget {
  const PlatformsPage({super.key});

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppScaffold(
      body: Column(
        children: <Widget>[
          DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small, vertical: AppSpacing.small),
              child: Row(
                children: <Widget>[
                  AppButtonIcon(
                    icon: AppIcon.arrowLeft,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  AppText(
                    l10n.availablePlatforms,
                    variant: AppTextVariant.title,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: AppLayout.platformPageWidth,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      platformItem(
                        _platformMacOS,
                        'assets/images/platforms/platformDesktopMacOS.png',
                        l10n.desktopSoftware,
                        _urlMacOSDownload,
                      ),
                      platformItem(
                        _platformWindows,
                        'assets/images/platforms/platformDesktopWindows.png',
                        l10n.desktopSoftware,
                        _urlWindowsDownload,
                      ),
                      platformItem(
                        _platformLinux,
                        'assets/images/platforms/platformDesktopLinux.png',
                        l10n.desktopSoftware,
                        _urlLinuxDownload,
                      ),
                      const SizedBox(
                        height: AppSpacing.largest,
                      ),
                      platformItem(
                        _platformIOS,
                        'assets/images/platforms/platformMobileIOS.png',
                        l10n.mobileApp,
                        _urlIOSApp,
                      ),
                      platformItem(
                        _platformAndroid,
                        'assets/images/platforms/platformMobileAndroid.png',
                        l10n.mobileApp,
                        _urlAndroidApp,
                      ),
                      const SizedBox(
                        height: AppSpacing.largest,
                      ),
                      platformItem(
                        l10n.webBrowser,
                        'assets/images/platforms/platformWeb.png',
                        l10n.runOnMostBrowsers,
                        _urlWebApp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small, horizontal: AppSpacing.large),
      child: AppCard(
        child: GestureDetector(
          onTap: () {
            launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
              webOnlyWindowName: '_blank',
            );
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Row(
                spacing: AppSpacing.large,
                children: <Widget>[
                  ClipOval(
                    child: SizedBox(
                      width: AppLayout.iconSize * AppVisual.previewTextScale,
                      height: AppLayout.iconSize * AppVisual.previewTextScale,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: AppColors.white),
                        child: Image.asset(image),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppText(name, variant: AppTextVariant.title),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: AppVisual.disabled,
                      child: AppText(description),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
