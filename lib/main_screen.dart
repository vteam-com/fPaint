import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'models/app_model.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    // Hide status bar and use full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    // Ensure that AppModel is provided above this widget in the widget tree and listening
    final AppModel appModel = AppModel.of(context, listen: true);

    appModel.deviceSizeSmall = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey,
      body: appModel.shellMode == ShellMode.hidden
          ? _buildMainContent(appModel)
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
              child: _buildMainContent(appModel),
            ),
      // Undo/Redo
      floatingActionButton: appModel.shellMode == ShellMode.hidden
          ? null
          : floatingActionButtons(appModel),
    );
  }

  Widget _buildMainContent(final AppModel appModel) {
    if (appModel.shellMode == ShellMode.hidden) {
      return MainView(
        canvasWidth: appModel.canvas.width,
        canvasHeight: appModel.canvas.height,
      );
    }

    if (appModel.deviceSizeSmall) {
      return _buildMobilePhoneLayout(appModel);
    }
    return _buildMidToLargeDevices(appModel);
  }

  Widget _buildMobilePhoneLayout(final AppModel appModel) {
    // On small device we either show the full screen canvas with a few floating action buttons
    if (appModel.showMenu) {
      return const SidePanel();
    } else {
      return MainView(
        canvasWidth: appModel.canvas.width,
        canvasHeight: appModel.canvas.height,
      );
    }
  }

  Widget _buildMidToLargeDevices(final AppModel appModel) {
    return MultiSplitView(
      key: Key('key_side_panel_size_${appModel.isSidePanelExpanded}'),
      axis: Axis.horizontal,
      onDividerDoubleTap: (dividerIndex) {
        appModel.isSidePanelExpanded = !appModel.isSidePanelExpanded;
      },
      initialAreas: [
        Area(
          size: appModel.isSidePanelExpanded ? 400 : minSidePanelSize,
          min: appModel.isSidePanelExpanded ? 350 : minSidePanelSize,
          max: appModel.isSidePanelExpanded ? 600 : minSidePanelSize,
          builder: (final BuildContext context, final Area area) =>
              const SidePanel(),
        ),
        Area(
          builder: (final BuildContext context, final Area area) => MainView(
            canvasWidth: appModel.canvas.width,
            canvasHeight: appModel.canvas.height,
          ),
        ),
      ],
    );
  }
}
