import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/panels/side_panel/about.dart';
import 'package:fpaint/panels/side_panel/canvas_settings.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free/material_free.dart';

/// A widget that displays the main menu.
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppPopupMenuButton<int>(
      key: Keys.mainMenuButton,
      tooltip: l10n.menuTooltip,
      icon: const AppSvgIcon(icon: AppIcon.menu),
      onSelected: (final int result) => onDropDownMenuSelection(context, result),
      itemBuilder: (final BuildContext _) => <AppPopupMenuItem<int>>[
        buildMenuItem(
          value: MenuIds.newFile,
          text: l10n.startOver,
          icon: AppIcon.powerSettingsNew,
        ),
        buildMenuItem(
          value: MenuIds.newFromClipboard,
          text: l10n.newFromClipboard,
          icon: AppIcon.clipboardPaste,
        ),
        buildMenuItem(
          value: MenuIds.openFile,
          text: l10n.importLabel,
          icon: AppIcon.fileDownload,
        ),
        buildMenuItem(
          value: MenuIds.export,
          text: l10n.exportLabel,
          icon: AppIcon.iosShare,
        ),
        if (!kIsWeb && shellProvider.loadedFileName.isNotEmpty)
          buildMenuItem(
            value: MenuIds.save,
            text: l10n.saveLabel,
            subtitle: shellProvider.loadedFileName,
            icon: AppIcon.checkCircle,
          ),
        buildMenuItem(
          value: MenuIds.canvasSize,
          text: l10n.canvas,
          icon: AppIcon.edit,
          key: Keys.mainMenuCanvasSize,
        ),
        buildMenuItem(
          value: MenuIds.settings,
          text: l10n.settings,
          icon: AppIcon.settings,
        ),
        buildMenuItem(
          value: MenuIds.platforms,
          text: l10n.platforms,
          icon: AppIcon.outbound,
        ),
        buildMenuItem(
          value: MenuIds.about,
          text: l10n.about,
          icon: AppIcon.info,
        ),
      ],
    );
  }
}

/// Handles the selection of a dropdown menu item.
void onDropDownMenuSelection(
  final BuildContext context,
  final int result,
) {
  final ShellProvider shellProvider = ShellProvider.of(context);
  final LayersProvider layers = LayersProvider.of(context);
  final AppLocalizations l10n = context.l10n;

  switch (result) {
    case MenuIds.newFile:
      onFileNew(context);
      break;
    case MenuIds.openFile:
      onFileOpen(context);
      break;
    case MenuIds.newFromClipboard:
      AppProvider.of(context).newDocumentFromClipboardImage();
      break;
    case MenuIds.save:
      saveFile(
        shellProvider,
        layers,
      ).then(
        // ignore: use_build_context_synchronously
        (final _) {
          layers.clearHasChanged();
          // ignore: use_build_context_synchronously
          context.showSnackBarMessage(
            l10n.savedMessage(shellProvider.loadedFileName),
          );
        },
      );
      break;

    case MenuIds.export:
      sharePanel(context);
      break;

    case MenuIds.canvasSize:
      showCanvasSettings(context);
      break;

    case MenuIds.settings:
      Navigator.pushNamed(context, '/settings');
      break;

    case MenuIds.platforms:
      Navigator.pushNamed(context, '/platforms');
      break;

    case MenuIds.about:
      showAboutBox(context);
      break;
  }
}

/// Builds a menu item.
AppPopupMenuItem<int> buildMenuItem({
  required final int value,
  required final String text,
  final String? subtitle,
  final AppIcon? icon,
  final Key? key,
}) {
  return AppPopupMenuItem<int>(
    value: value,
    child: Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) AppSvgIcon(icon: icon, size: AppSpacing.xl),
        if (icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.thin),
                Text(
                  subtitle,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: AppFontSize.subtitle,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
