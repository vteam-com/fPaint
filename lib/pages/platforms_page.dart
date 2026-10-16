import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/app_page_scaffold.dart';
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
const String _urlIOSApp = AppConfig.appStoreUrl;
const String _urlAndroidApp = AppConfig.googlePlayUrl;
const String _urlWebApp = 'https://paint.vteam.com';

/// A page that displays the available platforms for the application.
///
/// The iOS build leaves out the Google Play entry: App Review rejects apps
/// that reference other mobile platforms (guideline 2.3.10).
class PlatformsPage extends StatelessWidget {
  const PlatformsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppPageScaffold(
      title: l10n.availablePlatforms,
      contentWidth: AppLayout.platformPageWidth,
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
          if (!_isIOS)
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
    );
  }

  /// A widget that displays a platform item with an image, name, description, and URL.
  Widget platformItem(
    String name,
    String image,
    String description,
    String url,
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
                        child: Image.asset(image, package: appAssetsPackage),
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

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}
