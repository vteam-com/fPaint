import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
import 'package:url_launcher/url_launcher.dart';

const String _platformWindows = 'Windows';
const String _platformAndroid = 'Android';
const String _platformLinux = 'Linux';

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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  AppIconButton(
                    icon: const AppSvgIcon(icon: AppIcon.arrowLeft),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.availablePlatforms,
                    style: const TextStyle(
                      color: AppPalette.white,
                      fontSize: AppFontSize.titleHero,
                      fontWeight: FontWeight.bold,
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xl),
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
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                spacing: AppSpacing.xxl,
                children: <Widget>[
                  ClipOval(
                    child: SizedBox(
                      width: AppLayout.iconSize * AppVisual.previewTextScale,
                      height: AppLayout.iconSize * AppVisual.previewTextScale,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: AppPalette.white),
                        child: Image.asset(image),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(name, style: const TextStyle(fontSize: AppFontSize.titleHero)),
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
        ),
      ),
    );
  }
}
