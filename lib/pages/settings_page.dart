import 'package:flutter/material.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';

/// A page that allows the user to modify application settings.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 40,
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Use Apple Pencil Only'),
                  subtitle: const Text(
                    'If enabled, only the Apple Pencil will be used for drawing.',
                  ),
                  value: appProvider.preferences.useApplePencil,
                  onChanged: (final bool value) {
                    setState(() {
                      appProvider.preferences.setUseApplePencil(value);
                    });
                  },
                ),
                const Divider(),
                OutlinedButton(
                  onPressed: () {
                    showShortcutsHelp(context);
                  },
                  child: const Text('Keyboard Shortcuts'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
