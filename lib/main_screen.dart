import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/panels/side_panel/side_panel.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'providers/app_provider.dart';

/// The main screen of the application, which extends the `StatelessWidget` class.
/// This screen is responsible for rendering the main content of the app, including
/// the side panel, main view, and floating action buttons.
class MainScreen extends StatelessWidget {
  /// Creates a [MainScreen] widget.
  const MainScreen({super.key});

  /// The minimum size of the side panel.
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    final AppProvider appProvider = AppProvider.of(context, listen: true);

    if (appProvider.isPreferencesLoaded == false) {
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(
          child: CupertinoActivityIndicator(color: Colors.black, radius: 40),
        ),
      );
    }

    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);
    final ShellMode shellMode = shellProvider.shellMode;

    shellProvider.deviceSizeSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey,
      body: shellMode == ShellMode.hidden
          ? _buildMainContent(context, shellProvider, appProvider)
          : MultiSplitViewTheme(
              data: MultiSplitViewThemeData(
                dividerPainter: DividerPainters.grooved1(
                  animationEnabled: true,
                  backgroundColor: Colors.grey.shade600,
                  highlightedBackgroundColor: Colors.blue,
                  color: Colors.grey.shade800,
                  thickness: 6,
                  highlightedThickness: 8,
                  strokeCap: StrokeCap.round,
                ),
              ),
              child: _buildMainContent(context, shellProvider, appProvider),
            ),
      floatingActionButton: shellMode == ShellMode.hidden
          ? myFloatButton(
              icon: Icons.more_vert,
              onPressed: () {
                Future<void>.microtask(() {
                  shellProvider.shellMode = ShellMode.full;
                  shellProvider.update();
                });
              },
            )
          : floatingActionButtons(context, shellProvider, appProvider),
    );
  }

  /// Builds the main content of the application based on the current shell mode.
  ///
  /// If the shell mode is hidden, the main view is returned. Otherwise, a multi-split view
  /// is returned, which contains the side panel and main view.
  Widget _buildMainContent(
    final BuildContext context,
    final ShellProvider shellProvider,
    final AppProvider appProvider,
  ) {
    if (shellProvider.shellMode == ShellMode.hidden) {
      return const MainView();
    }

    if (shellProvider.deviceSizeSmall) {
      return _buildMobilePhoneLayout(context, shellProvider, appProvider);
    }
    return _buildMidToLargeDevices(shellProvider, appProvider);
  }

  /// Builds the layout for mid-to-large devices.
  ///
  /// A multi-split view is returned, which contains the side panel and main view.
  Widget _buildMidToLargeDevices(
    final ShellProvider shellProvider,
    final AppProvider appProvider,
  ) {
    return MultiSplitView(
      key: Key('key_side_panel_size_${shellProvider.isSidePanelExpanded}'),
      axis: Axis.horizontal,
      onDividerDoubleTap: (final int dividerIndex) {
        shellProvider.isSidePanelExpanded = !shellProvider.isSidePanelExpanded;
      },
      initialAreas: <Area>[
        Area(
          size: shellProvider.isSidePanelExpanded ? 400 : minSidePanelSize,
          min: shellProvider.isSidePanelExpanded ? 350 : minSidePanelSize,
          max: shellProvider.isSidePanelExpanded ? 600 : minSidePanelSize,
          builder: (final BuildContext context, final Area area) => SidePanel(
            minimal: !shellProvider.isSidePanelExpanded,
            preferences: appProvider.preferences,
          ),
        ),
        Area(
          builder: (final BuildContext context, final Area area) => const MainView(),
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
    final AppProvider appProvider,
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
                color: Colors.black.withAlpha(128), // Semi-transparent overlay
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
                    child: SidePanel(
                      minimal: false, // Always show full panel on mobile
                      preferences: appProvider.preferences,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
