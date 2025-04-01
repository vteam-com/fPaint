import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays an about dialog with information about the application.
///
/// This function shows a dialog box that includes the application's name,
/// version, legal information, and an icon. It also displays the device's
/// screen resolution and a link to the application's GitHub repository.
///
/// The [context] parameter is the [BuildContext] used to show the dialog.
void showAboutBox(final BuildContext context) {
  final MediaQueryData mediaQuery = MediaQuery.of(context);
  final String screenResolution =
      '${mediaQuery.size.width.toInt()} x ${mediaQuery.size.height.toInt()}';

  showAboutDialog(
    context: context,
    applicationName: 'fPaint',
    applicationVersion: '1.0.0',
    applicationLegalese: '© 2025 VTeam',
    applicationIcon: Image.asset(
      'assets/app_icon.png',
      width: 100,
      height: 100,
    ),
    children: <Widget>[
      const SizedBox(height: 20),
      Text('Device Screen Resolution: $screenResolution'),
      const SizedBox(height: 20),
      InkWell(
        child: const Text(
          'GitHub Repo',
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
        onTap: () => launchUrl(Uri.parse('https://github.com/your-repo-url')),
      ),
    ],
  );
}
