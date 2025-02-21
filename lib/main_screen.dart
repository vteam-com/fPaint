import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'providers/app_provider.dart';

/// The main screen of the application, which extends the `StatelessWidget` class.
/// This screen is responsible for rendering the main content of the app, including
/// the side panel, main view, and floating action buttons.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    final AppProvider appProvider = AppProvider.of(context, listen: true);
    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);
    final ShellMode shellMode = shellProvider.shellMode;

    shellProvider.deviceSizeSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey,
      body: shellMode == ShellMode.hidden
          ? _buildMainContent(shellProvider)
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
              child: _buildMainContent(shellProvider),
            ),
      floatingActionButton: shellMode == ShellMode.hidden
          ? null
          : floatingActionButtons(shellProvider, appProvider),
    );
  }

  Widget _buildMainContent(final ShellProvider shellProvider) {
    if (shellProvider.shellMode == ShellMode.hidden) {
      return const MainView();
    }

    if (shellProvider.deviceSizeSmall) {
      return _buildMobilePhoneLayout(shellProvider);
    }
    return _buildMidToLargeDevices(shellProvider);
  }

  Widget _buildMobilePhoneLayout(final ShellProvider shellProvider) {
    if (shellProvider.showMenu) {
      return const SidePanel();
    } else {
      return const MainView();
    }
  }

  Widget _buildMidToLargeDevices(final ShellProvider shellProvider) {
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
          builder: (final BuildContext context, final Area area) =>
              const SidePanel(),
        ),
        Area(
          builder: (final BuildContext context, final Area area) =>
              const MainView(),
        ),
      ],
    );
  }
}
