import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A page that displays the available platforms for the application.
class PlatformsPage extends StatelessWidget {
  const PlatformsPage({super.key});

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Platforms')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                platformItem(
                  'macOS',
                  'assets/images/platforms/platformDesktopMacOS.png',
                  'Desktop Software.',
                  'https://paint.vteam.com/downloads/flutter-macos-app.zip',
                ),
                platformItem(
                  'Windows',
                  'assets/images/platforms/platformDesktopWindows.png',
                  'Desktop Software.',
                  'https://paint.vteam.com/downloads/flutter-windows-app.zip',
                ),
                platformItem(
                  'Linux',
                  'assets/images/platforms/platformDesktopLinux.png',
                  'Desktop Software.',
                  'https://paint.vteam.com/downloads/flutter-linux-app.zip',
                ),
                const SizedBox(
                  height: 40,
                ),
                platformItem(
                  'iOS',
                  'assets/images/platforms/platformMobileIOS.png',
                  'Mobile app.',
                  'https://apps.apple.com/us/app/cooking-timer-by-vteam/id1188460815',
                ),
                platformItem(
                  'Android',
                  'assets/images/platforms/platformMobileAndroid.png',
                  'Mobile app.',
                  'https://play.google.com/store/apps/details?id=com.vteam.cookingtimerflutter',
                ),
                const SizedBox(
                  height: 40,
                ),
                platformItem(
                  'Web Browser',
                  'assets/images/platforms/platformWeb.png',
                  'Run on any OS with most browsers.',
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
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          launchUrl(Uri.parse(url));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 20,
            children: <Widget>[
              CircleAvatar(
                backgroundColor: Colors.white,
                foregroundImage: AssetImage(image),
              ),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 18))),
              Expanded(
                child: Opacity(
                  opacity: 0.8,
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
