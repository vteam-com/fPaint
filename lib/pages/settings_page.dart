import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';

/// A page that allows the user to modify application settings.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _languageCodeEn = 'en';
  static const String _languageCodeEs = 'es';
  static const String _languageCodeFr = 'fr';
  static const String _systemLanguage = 'system';
  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final AppLocalizations l10n = context.l10n;

    final String selectedLanguage = appProvider.languageCode ?? _systemLanguage;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: SizedBox(
          width: AppLayout.dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxl,
              children: <Widget>[
                ListTile(
                  title: Text(l10n.languageLabel),
                  subtitle: Text(l10n.languageSubtitle),
                  trailing: DropdownButton<String>(
                    value: selectedLanguage,
                    onChanged: (final String? value) {
                      if (value == null) {
                        return;
                      }

                      final String? languageCode = value == _systemLanguage ? null : value;
                      appProvider.setLanguageCode(languageCode);
                    },
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: _systemLanguage,
                        child: Text(l10n.languageSystem),
                      ),
                      DropdownMenuItem<String>(
                        value: _languageCodeEn,
                        child: Text(l10n.languageEnglish),
                      ),
                      DropdownMenuItem<String>(
                        value: _languageCodeFr,
                        child: Text(l10n.languageFrench),
                      ),
                      DropdownMenuItem<String>(
                        value: _languageCodeEs,
                        child: Text(l10n.languageSpanish),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(l10n.useApplePencilOnlyTitle),
                  subtitle: Text(l10n.useApplePencilOnlySubtitle),
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
                  child: Text(l10n.keyboardShortcuts),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
