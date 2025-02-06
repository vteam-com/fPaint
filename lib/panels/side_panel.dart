import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers/tools_and_layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:multi_split_view/multi_split_view.dart';

class SidePanel extends StatefulWidget {
  const SidePanel({super.key});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  @override
  Widget build(BuildContext context) {
    final AppModel appModel = AppModel.get(context);

    return Material(
      elevation: 18,
      color: Colors.grey.shade800,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerPainter: DividerPainters.dashed(
            animationEnabled: true,
            color: Colors.grey,
            highlightedColor: Colors.blue,
            highlightedThickness: 4,
            strokeCap: StrokeCap.round,
          ),
        ),
        child: MultiSplitView(
          axis: Axis.vertical,
          initialAreas: [
            Area(
              size: 200,
              min: 100,
              builder: (context, area) => const ToolsAndLayersPanel(),
            ),
            Area(
              size: 400,
              min: 100,
              builder: (context, area) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ToolsPanel(
                  currentShapeType: appModel.selectedTool,
                  onShapeSelected: (Tools tool) => appModel.selectedTool = tool,
                  minimal: !appModel.isSidePanelExpanded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
