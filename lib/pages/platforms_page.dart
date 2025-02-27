import 'package:flutter/material.dart';

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
                paltformItem(
                  'macOS',
                  'assets/images/platforms/platformDesktopMacOS.png',
                  'Desktop Software.',
                ),
                paltformItem(
                  'Windows',
                  'assets/images/platforms/platformDesktopWindows.png',
                  'Desktop Software.',
                ),
                paltformItem(
                  'Linux',
                  'assets/images/platforms/platformDesktopLinux.png',
                  'Desktop Software.',
                ),
                const SizedBox(
                  height: 40,
                ),
                paltformItem(
                  'iOS',
                  'assets/images/platforms/platformMobileIOS.png',
                  'Mobile app.',
                ),
                paltformItem(
                  'Android',
                  'assets/images/platforms/platformMobileAndroid.png',
                  'Mobile app.',
                ),
                const SizedBox(
                  height: 40,
                ),
                paltformItem(
                  'Web Browser',
                  'assets/images/platforms/platformWeb.png',
                  'Run on any OS with most browsers.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget paltformItem(
    final String name,
    final String image,
    final String description,
  ) {
    return MaterialButton(
      elevation: 9,
      padding: const EdgeInsets.all(20),
      onPressed: () {},
      child: Row(
        spacing: 20,
        children: <Widget>[
          CircleAvatar(
            backgroundImage: AssetImage(image),
          ),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 20))),
          Expanded(
            child: Opacity(
              opacity: 0.8,
              child: Text(description),
            ),
          ),
        ],
      ),
    );
  }
}
