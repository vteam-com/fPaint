import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void showAboutBox(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final screenResolution =
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
    children: [
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
