import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'providers/app_provider.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    final AppProvider appModel = AppProvider.of(context, listen: true);
    final ShellProvider shellModel = ShellProvider.of(context, listen: true);
    final ShellMode shellMode = shellModel.shellMode;

    shellModel.deviceSizeSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey,
      body: shellMode == ShellMode.hidden
          ? _buildMainContent(shellModel)
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
              child: _buildMainContent(shellModel),
            ),
      floatingActionButton: shellMode == ShellMode.hidden
          ? null
          : floatingActionButtons(shellModel, appModel),
    );
  }

  Widget _buildMainContent(final ShellProvider shellModel) {
    if (shellModel.shellMode == ShellMode.hidden) {
      return const MainView();
    }

    if (shellModel.deviceSizeSmall) {
      return _buildMobilePhoneLayout(shellModel);
    }
    return _buildMidToLargeDevices(shellModel);
  }

  Widget _buildMobilePhoneLayout(final ShellProvider shellModel) {
    if (shellModel.showMenu) {
      return const SidePanel();
    } else {
      return const MainView();
    }
  }

  Widget _buildMidToLargeDevices(final ShellProvider shellModel) {
    return MultiSplitView(
      key: Key('key_side_panel_size_${shellModel.isSidePanelExpanded}'),
      axis: Axis.horizontal,
      onDividerDoubleTap: (final int dividerIndex) {
        shellModel.isSidePanelExpanded = !shellModel.isSidePanelExpanded;
      },
      initialAreas: <Area>[
        Area(
          size: shellModel.isSidePanelExpanded ? 400 : minSidePanelSize,
          min: shellModel.isSidePanelExpanded ? 350 : minSidePanelSize,
          max: shellModel.isSidePanelExpanded ? 600 : minSidePanelSize,
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
