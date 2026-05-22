import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/panels/side_panel/top_menu_and_layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The `SidePanel` widget is a stateful widget that represents the side panel of the application.
/// It uses the `MultiSplitView` widget to display the top menu and layers panel, as well as the tools panel.
/// The side panel is styled with a material elevation and a rounded border on the top-right and bottom-right corners.
/// The `MultiSplitViewTheme` is used to customize the appearance of the divider between the two panels.
class SidePanel extends StatefulWidget {
  const SidePanel({
    super.key,
    required this.minimal,
    required this.preferences,
  });

  /// A boolean indicating whether the side panel should be displayed in minimal mode.
  final bool minimal;

  /// The app preferences.
  final AppPreferences preferences;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  final MultiSplitViewController _splitController = MultiSplitViewController();
  @override
  void initState() {
    super.initState();

    final double topPanelHeight = widget.preferences.sidePanelDistance;

    _splitController.areas = <Area>[
      Area(
        size: topPanelHeight,
        min: AppLayout.minPanelExtent,
        builder: (final BuildContext _, final Area _) => const TopMenuAndLayersPanel(),
      ),
      Area(
        min: AppLayout.minPanelExtent,
        builder: (final BuildContext _, final Area _) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.small),
          child: ToolsPanel(
            minimal: widget.minimal,
          ),
        ),
      ),
    ];

    // start listening to user change
    _splitController.addListener(_rebuild);
  }

  @override
  void dispose() {
    super.dispose();
    _splitController.removeListener(_rebuild);
  }

  @override
  Widget build(final BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context, listen: true);
    if (_isModifyMode(appProvider)) {
      return _buildModifyModePanel(context, appProvider);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.shellChromeBackground),
      child: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.grooved1(
            animationEnabled: true,
            backgroundColor: AppColors.shellChromeBackground,
            highlightedBackgroundColor: AppColors.shellChromeDividerHighlight,
            color: AppColors.shellChromeDivider,
            thickness: AppStroke.divider,
            highlightedThickness: AppStroke.dividerHighlighted,
            strokeCap: StrokeCap.round,
          ),
        ),
        child: MultiSplitView(
          controller: _splitController,
          axis: Axis.vertical,
        ),
      ),
    );
  }

  /// Builds the minimal side panel shown while a layer Modify session is active.
  Widget _buildModifyModePanel(
    final BuildContext context,
    final AppProvider appProvider,
  ) {
    final AppLocalizations l10n = context.l10n;

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.shellChromeBackground),
      child: LayoutBuilder(
        builder: (final BuildContext _, final BoxConstraints constraints) {
          final double horizontalPadding;
          if (constraints.maxWidth <= AppLayout.sidePanelCollapsed + AppLayout.toolbarButtonWidth) {
            horizontalPadding = AppSpacing.small;
          } else if (constraints.maxWidth <=
              AppLayout.sidePanelCollapsed + AppLayout.toolbarButtonWidth + AppSpacing.large) {
            horizontalPadding = AppSpacing.medium;
          } else {
            horizontalPadding = AppSpacing.large;
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.large,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppText(l10n.layerModify, variant: AppTextVariant.title),
                const Spacer(),
                AppButtonRow(
                  actions: <Widget>[
                    AppRowSecondaryButton(
                      onPressed: () {
                        Future<void>.microtask(() async {
                          if (appProvider.transformModel.isVisible) {
                            appProvider.cancelTransform();
                            return;
                          }
                          appProvider.cancelImagePlacement();
                        });
                      },
                      text: l10n.cancel,
                    ),
                    AppRowPrimaryButton(
                      onPressed: () {
                        Future<void>.microtask(() async {
                          if (appProvider.transformModel.isVisible) {
                            await appProvider.confirmTransform();
                            return;
                          }
                          await appProvider.confirmImagePlacement();
                        });
                      },
                      text: l10n.apply,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isModifyMode(final AppProvider appProvider) {
    return appProvider.imagePlacementModel.commitMode == ImagePlacementCommitMode.replaceLayer &&
        appProvider.imagePlacementModel.layerRestoreState != null;
  }

  /// Rebuilds the widget when the split controller changes.
  void _rebuild() async {
    final double? heightOfTopSection = _splitController.areas[0].size;
    if (heightOfTopSection != null) {
      await widget.preferences.setSidePanelDistance(heightOfTopSection);
    }
  }
}
