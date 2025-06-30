import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/models/localized_strings.dart';
import 'package:fpaint/panels/share_panel.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/providers/app_provider.dart'; // Added for AppProvider
import 'package:fpaint/providers/shell_provider.dart';

/// A widget that displays the top menu of the side panel.
class SidePanelTopMenu extends StatelessWidget {
  const SidePanelTopMenu({
    super.key,
    required this.shellProvider,
  });

  /// The shell provider.
  final ShellProvider shellProvider;

  /// Builds an icon button.
  Widget buildIconButton({
    required final String tooltip,
    required final IconData icon,
    required final VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(final BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const MainMenu(),
        if (shellProvider.isSidePanelExpanded)
          buildIconButton(
            tooltip: strings[StringId.startOver]!,
            icon: Icons.power_settings_new_outlined,
            onPressed: () => onFileNew(context),
          ),
        if (shellProvider.isSidePanelExpanded)
          buildIconButton(
            tooltip: strings[StringId.importTooltip]!,
            icon: Icons.file_download_outlined,
            onPressed: () => onFileOpen(context),
          ),
        if (shellProvider.isSidePanelExpanded)
          buildIconButton(
            tooltip: strings[StringId.exportTooltip]!,
            icon: Icons.ios_share_outlined,
            onPressed: () => sharePanel(context),
          ),
        if (shellProvider.isSidePanelExpanded) // Show when panel is expanded
          buildIconButton(
            tooltip: 'Rotate Canvas 90° CW', // TODO: Localize this string
            icon: Icons.rotate_90_degrees_cw_outlined,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.rotateCanvas90();
            },
          ),
        if (!shellProvider.showMenu)
          buildIconButton(
            tooltip: strings[StringId.exportTooltip]!,
            icon: shellProvider.isSidePanelExpanded
                ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_double_arrow_right,
            onPressed: () {
              shellProvider.isSidePanelExpanded = !shellProvider.isSidePanelExpanded;
            },
          ),
      ],
    );
  }
}

/// Builds an icon button.
Widget buildIconButton({
  required final String tooltip,
  required final IconData icon,
  required final VoidCallback onPressed,
}) {
  return IconButton(
    tooltip: tooltip,
    icon: Icon(icon),
    onPressed: onPressed,
  );
}
