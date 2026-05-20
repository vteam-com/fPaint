import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/image_placement_layer_restore_state.dart';
import 'package:fpaint/panels/side_panel/side_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The main screen of the application, which extends the `StatelessWidget` class.
/// This screen is responsible for rendering the main content of the app, including
/// the side panel, main view, and floating action buttons.
class MainScreen extends StatelessWidget {
  /// Creates a [MainScreen] widget.
  const MainScreen({super.key});

  /// The minimum size of the side panel.
  final double minSidePanelSize = AppLayout.sidePanelCollapsed;
  @override
  Widget build(final BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    final AppPreferences appPreferences = AppPreferences.of(context, listen: true);
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    if (appPreferences.isLoaded == false) {
      return const AppScaffold(
        backgroundColor: AppColors.shellChromeBackground,
        body: Center(
          child: SizedBox(
            width: AppLayout.loaderRadius,
            height: AppLayout.loaderRadius,
            child: AppProgressIndicator(),
          ),
        ),
      );
    }

    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);
    final ShellMode shellMode = shellProvider.shellMode;
    final bool hasActiveTransformOverlay = appProvider.hasActiveTransformOverlay;
    final bool isModifyMode =
        appProvider.imagePlacementModel.commitMode == ImagePlacementCommitMode.replaceLayer &&
        appProvider.imagePlacementModel.layerRestoreState != null;

    shellProvider.deviceSizeSmall = MediaQuery.of(context).size.width < AppLayout.desktopBreakpoint;

    return DropTarget(
      onDragDone: (final DropDoneDetails details) {
        _handleDroppedFiles(context, details);
      },
      child: AppScaffold(
        backgroundColor: AppColors.shellChromeBackground,
        body: Stack(
          children: <Widget>[
            shellMode == ShellMode.hidden
                ? _buildMainContent(context, shellProvider, appPreferences, hasActiveTransformOverlay, isModifyMode)
                : MultiSplitViewTheme(
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
                    child: _buildMainContent(
                      context,
                      shellProvider,
                      appPreferences,
                      hasActiveTransformOverlay,
                      isModifyMode,
                    ),
                  ),
            Positioned(
              right: AppSpacing.large,
              bottom: AppSpacing.large,
              child: shellMode == ShellMode.hidden
                  ? AppButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: AppLayout.toolbarButtonSize,
                        height: AppLayout.toolbarButtonSize,
                      ),
                      onPressed: () {
                        Future<void>.microtask(() {
                          shellProvider.shellMode = ShellMode.full;
                          shellProvider.update();
                        });
                      },
                      child: const SizedBox(
                        width: AppLayout.toolbarButtonSize,
                        height: AppLayout.toolbarButtonSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.floatingButtonBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AppSvgIcon(icon: AppIcon.moreVert),
                          ),
                        ),
                      ),
                    )
                  : floatingActionButtons(context, shellProvider, appProvider),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the main content of the application based on the current shell mode.
  ///
  /// If the shell mode is hidden, the main view is returned. Otherwise, a multi-split view
  /// is returned, which contains the side panel and main view.
  Widget _buildMainContent(
    final BuildContext context,
    final ShellProvider shellProvider,
    final AppPreferences appPreferences,
    final bool hasActiveTransformOverlay,
    final bool isModifyMode,
  ) {
    if (hasActiveTransformOverlay && !isModifyMode) {
      return const MainView();
    }

    if (shellProvider.shellMode == ShellMode.hidden) {
      return const MainView();
    }

    if (shellProvider.deviceSizeSmall) {
      return _buildMobilePhoneLayout(context, shellProvider, appPreferences);
    }
    return _buildMidToLargeDevices(shellProvider, appPreferences);
  }

  /// Builds the layout for mid-to-large devices.
  ///
  /// A multi-split view is returned, which contains the side panel and main view.
  Widget _buildMidToLargeDevices(
    final ShellProvider shellProvider,
    final AppPreferences appPreferences,
  ) {
    return MultiSplitView(
      key: Key('key_side_panel_size_${shellProvider.isSidePanelExpanded}'),
      axis: Axis.horizontal,
      onDividerDoubleTap: (final int _) {
        shellProvider.isSidePanelExpanded = !shellProvider.isSidePanelExpanded;
      },
      initialAreas: <Area>[
        Area(
          size: shellProvider.isSidePanelExpanded ? AppLayout.sidePanelExpanded : minSidePanelSize,
          min: shellProvider.isSidePanelExpanded ? AppLayout.sidePanelExpandedMin : minSidePanelSize,
          max: shellProvider.isSidePanelExpanded ? AppLayout.sidePanelExpandedMax : minSidePanelSize,
          builder: (final BuildContext _, final Area _) => SidePanel(
            minimal: !shellProvider.isSidePanelExpanded,
            preferences: appPreferences,
          ),
        ),
        Area(
          builder: (final BuildContext _, final Area _) => const MainView(),
        ),
      ],
    );
  }

  /// Builds the layout for mobile phone devices.
  ///
  /// Uses a stack layout where the main view is always visible,
  /// and the side panel can be shown as an overlay when needed.
  Widget _buildMobilePhoneLayout(
    final BuildContext context,
    final ShellProvider shellProvider,
    final AppPreferences appPreferences,
  ) {
    return Stack(
      children: <Widget>[
        const MainView(),
        if (shellProvider.showMenu)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                shellProvider.showMenu = false;
                shellProvider.update();
              },
              child: Container(
                color: AppColors.black.withAlpha(AppLayout.overlayAlpha),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * AppLayout.mobileMenuWidthFactor,
                    child: SidePanel(
                      minimal: false, // Always show full panel on mobile
                      preferences: appPreferences,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Handles files dropped onto the main screen from the desktop.
  void _handleDroppedFiles(
    final BuildContext context,
    final DropDoneDetails details,
  ) {
    // Only handle file drops on non-web platforms where file paths are
    // available.
    if (kIsWeb) {
      return;
    }

    for (final DropItem xFile in details.files) {
      final String path = xFile.path;
      if (path.isNotEmpty) {
        onFileDropped(context: context, path: path);
        // Only handle the first file.
        break;
      }
    }
  }
}
