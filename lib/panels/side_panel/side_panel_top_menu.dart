import 'package:flutter/widgets.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/side_panel/menu.dart';
import 'package:fpaint/panels/side_panel/recent_files_dialog.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/material_free.dart';

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
        if (shellProvider.isSidePanelExpanded)
          AppButtonIcon(
            tooltip: l10n.startOverTooltip,
            icon: AppIcon.powerSettingsNew,
            onPressed: () => onFileNew(context),
          ),
        if (shellProvider.isSidePanelExpanded)
          AppButtonIcon(
            tooltip: l10n.importTooltip,
            icon: AppIcon.fileDownload,
            onPressed: () => showAppBottomSheet<void>(
              context: context,
              builder: (final BuildContext _) {
                return ImportDialog(parentContext: context);
              },
            ),
          ),
        if (shellProvider.isSidePanelExpanded)
          AppButtonIcon(
            key: Keys.sidePanelExportButton,
            tooltip: l10n.exportTooltip,
            icon: AppIcon.iosShare,
            onPressed: () => sharePanel(context),
          ),
        if (shellProvider.isSidePanelExpanded) // Show when panel is expanded
          AppButtonIcon(
            tooltip: l10n.rotateCanvasTooltip,
            icon: AppIcon.rotate90DegreesCw,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.rotateCanvas90(l10n.rotateCanvasTooltip);
              shellProvider.requestCanvasFit();
            },
          ),
        if (shellProvider.isSidePanelExpanded)
          AppButtonIcon(
            tooltip: l10n.flipHorizontalTooltip,
            icon: AppIcon.flipHorizontal,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.flipCanvasHorizontal(l10n.flipHorizontalTooltip);
              shellProvider.requestCanvasFit();
            },
          ),
        if (shellProvider.isSidePanelExpanded)
          AppButtonIcon(
            tooltip: l10n.flipVerticalTooltip,
            icon: AppIcon.flipVertical,
            onPressed: () async {
              final AppProvider appProvider = AppProvider.of(context);
              await appProvider.flipCanvasVertical(l10n.flipVerticalTooltip);
              shellProvider.requestCanvasFit();
            },
          ),
        if (!shellProvider.showMenu)
          AppButtonIcon(
            tooltip: l10n.exportTooltip,
            icon: shellProvider.isSidePanelExpanded
                ? AppIcon.keyboardDoubleArrowLeft
                : AppIcon.keyboardDoubleArrowRight,
            onPressed: () {
              shellProvider.isSidePanelExpanded = !shellProvider.isSidePanelExpanded;
            },
          ),
        const MainMenu(),
      ],
    );
  }
}
