import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_svg_icon.dart';

/// A widget that displays the top menu of the side panel.
class SidePanelTopMenu extends StatelessWidget {
  const SidePanelTopMenu({
    super.key,
    required this.shellProvider,
  });

  /// The shell provider.
  final ShellProvider shellProvider;

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const MainMenu(),
        if (shellProvider.isSidePanelExpanded)
          _buildIconButton(
            tooltip: l10n.startOverTooltip,
            icon: AppIcon.powerSettingsNew,
            onPressed: () => onFileNew(context),
          ),
        if (shellProvider.isSidePanelExpanded)
          _buildIconButton(
            tooltip: l10n.importTooltip,
            icon: AppIcon.fileDownload,
            onPressed: () => onFileOpen(context),
          ),
        if (shellProvider.isSidePanelExpanded)
          _buildIconButton(
            tooltip: l10n.exportTooltip,
            icon: AppIcon.iosShare,
            onPressed: () => sharePanel(context),
          ),
        if (shellProvider.isSidePanelExpanded) // Show when panel is expanded
          _buildIconButton(
            tooltip: l10n.rotateCanvasTooltip,
            icon: AppIcon.rotate90DegreesCw,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.rotateCanvas90();
            },
          ),
        if (shellProvider.isSidePanelExpanded)
          _buildIconButton(
            tooltip: l10n.flipHorizontalTooltip,
            icon: AppIcon.flipHorizontal,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.flipCanvasHorizontal(l10n.flipHorizontalTooltip);
            },
          ),
        if (shellProvider.isSidePanelExpanded)
          _buildIconButton(
            tooltip: l10n.flipVerticalTooltip,
            icon: AppIcon.flipVertical,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.flipCanvasVertical(l10n.flipVerticalTooltip);
            },
          ),
        if (!shellProvider.showMenu)
          _buildIconButton(
            tooltip: l10n.exportTooltip,
            icon: shellProvider.isSidePanelExpanded
                ? AppIcon.keyboardDoubleArrowLeft
                : AppIcon.keyboardDoubleArrowRight,
            onPressed: () {
              shellProvider.isSidePanelExpanded = !shellProvider.isSidePanelExpanded;
            },
          ),
      ],
    );
  }
}

/// Builds an icon button.
Widget _buildIconButton({
  required final String tooltip,
  required final AppIcon icon,
  required final VoidCallback onPressed,
}) {
  return IconButton(
    tooltip: tooltip,
    icon: AppSvgIcon(icon: icon),
    onPressed: onPressed,
  );
}
