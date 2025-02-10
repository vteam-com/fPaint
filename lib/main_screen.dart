import 'package:flutter/material.dart';
import 'package:fpaint/floating_buttons.dart';
import 'package:fpaint/panels/side_panel.dart';
import 'package:fpaint/widgets/canvas_widget.dart';
import 'package:multi_split_view/multi_split_view.dart';

import 'models/app_model.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  final double minSidePanelSize = 100.0;

  @override
  Widget build(final BuildContext context) {
    // Ensure that AppModel is provided above this widget in the widget tree and listening
    final AppModel appModel = AppModel.of(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.grey,
      body: MultiSplitViewTheme(
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
        child: MultiSplitView(
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
              builder: (final BuildContext context, final Area area) =>
                  CanvasWidget(
                canvasWidth: appModel.canvas.width,
                canvasHeight: appModel.canvas.height,
              ),
            ),
          ],
        ),
      ),
      // Undo/Redo
      floatingActionButton: floatingActionButtons(appModel),
    );
  }
}
