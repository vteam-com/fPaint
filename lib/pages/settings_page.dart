import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';
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
    final AppPreferences appPreferences = AppPreferences.of(context, listen: true);
    final AppLocalizations l10n = context.l10n;

    final String selectedLanguage = appPreferences.languageCode ?? _systemLanguage;

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
                    l10n.settings,
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
                width: AppLayout.dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xxl,
                    children: <Widget>[
                      AppListTile(
                        title: Text(l10n.languageLabel),
                        subtitle: Text(l10n.languageSubtitle),
                        trailing: AppDropdown<String>(
                          value: selectedLanguage,
                          onChanged: (final String? value) {
                            if (value == null) {
                              return;
                            }

                            final String? languageCode = value == _systemLanguage ? null : value;
                            appPreferences.setLanguageCode(languageCode);
                          },
                          items: <AppDropdownItem<String>>[
                            AppDropdownItem<String>(
                              value: _systemLanguage,
                              child: Text(l10n.languageSystem),
                            ),
                            AppDropdownItem<String>(
                              value: _languageCodeEn,
                              child: Text(l10n.languageEnglish),
                            ),
                            AppDropdownItem<String>(
                              value: _languageCodeFr,
                              child: Text(l10n.languageFrench),
                            ),
                            AppDropdownItem<String>(
                              value: _languageCodeEs,
                              child: Text(l10n.languageSpanish),
                            ),
                          ],
                        ),
                      ),
                      const AppDivider(),
                      AppListTile(
                        title: Text(l10n.useApplePencilOnlyTitle),
                        subtitle: Text(l10n.useApplePencilOnlySubtitle),
                        trailing: AppToggleSwitch(
                          value: appPreferences.useApplePencil,
                          onChanged: (final bool value) {
                            setState(() {
                              appPreferences.setUseApplePencil(value);
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            appPreferences.setUseApplePencil(!appPreferences.useApplePencil);
                          });
                        },
                      ),
                      const AppDivider(),
                      AppTextButton(
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
          ),
        ],
      ),
    );
  }
}
