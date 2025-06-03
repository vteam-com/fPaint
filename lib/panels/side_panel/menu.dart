import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/models/localized_strings.dart';
import 'package:fpaint/models/menu_model.dart';
import 'package:fpaint/panels/about.dart';
import 'package:fpaint/panels/canvas_settings.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// A widget that displays the main menu.
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context);

    return PopupMenuButton<int>(
      tooltip: strings[StringId.menuTooltip],
      icon: const Icon(Icons.menu),
      onSelected: (final int result) => onDropDownMenuSelection(context, result),
      itemBuilder: (final BuildContext context) => <PopupMenuEntry<int>>[
        buildMenuItem(
          value: MenuIds.newFile,
          text: strings[StringId.startOver]!,
          icon: Icons.power_settings_new_outlined,
        ),
        buildMenuItem(
          value: MenuIds.openFile,
          text: strings[StringId.import]!,
          icon: Icons.file_download_outlined,
        ),
        buildMenuItem(
          value: MenuIds.newFromClipboard,
          text: 'New from Clipboard', // TODO(you): localize this string
          icon: Icons.content_paste_go,
        ),
        buildMenuItem(
          value: MenuIds.export,
          text: strings[StringId.export]!,
          icon: Icons.ios_share_outlined,
        ),
        if (!kIsWeb && shellProvider.loadedFileName.isNotEmpty)
          buildMenuItem(
            value: MenuIds.save,
            text: 'Save "${shellProvider.loadedFileName}"',
            icon: Icons.check_circle_outline,
          ),
        buildMenuItem(
          value: MenuIds.canvasSize,
          text: strings[StringId.canvas]!,
          icon: Icons.edit,
        ),
        buildMenuItem(
          value: MenuIds.settings,
          text: strings[StringId.settings]!,
          icon: Icons.settings,
        ),
        buildMenuItem(
          value: MenuIds.platforms,
          text: strings[StringId.platforms]!,
          icon: Icons.outbound_sharp,
        ),
        buildMenuItem(
          value: MenuIds.about,
          text: strings[StringId.about]!,
          icon: Icons.info_outline,
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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${strings[StringId.savedMessage]}${shellProvider.loadedFileName}',
                ),
              ),
            );
          }
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
PopupMenuEntry<int> buildMenuItem({
  required final int value,
  required final String text,
  final IconData? icon,
  final VoidCallback? onPressed,
}) {
  return PopupMenuItem<int>(
    value: value,
    child: Row(
      children: <Widget>[
        if (icon != null) Icon(icon, size: 18),
        if (icon != null) const SizedBox(width: 8),
        Text(text),
      ],
    ),
  );
}
