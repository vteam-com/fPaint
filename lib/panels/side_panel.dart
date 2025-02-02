import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers/tools_and_layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';

class SidePanel extends StatefulWidget {
  const SidePanel({super.key});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  double topPanelHeight = 200.0; // Initial height for the top panel

  @override
  Widget build(final BuildContext context) {
    final AppModel appModel = AppModel.get(context, listen: true);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: appModel.isSidePanelExpanded ? 360 : 80,
      child: Material(
        elevation: 18,
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        clipBehavior: Clip.none,
        child: Column(
          children: [
            //
            // Tools and Layers Panel
            //
            SizedBox(
              height: topPanelHeight,
              child: const ToolsAndLayersPanel(),
            ),
            //
            // Resizable Slipper
            //
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                setState(() {
                  topPanelHeight += details.delta.dy;

                  // Ensure the height is within a reasonable range
                  if (topPanelHeight < 50) {
                    topPanelHeight = 50;
                  }
                  if (topPanelHeight >
                      MediaQuery.of(context).size.height - 100) {
                    topPanelHeight = MediaQuery.of(context).size.height - 100;
                  }
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Divider(
                  thickness: 4,
                  height: 8,
                  color: Colors.grey,
                ),
              ),
            ),
            //
            // Tools Panel
            //
            Expanded(
              child: ToolsPanel(
                currentShapeType: appModel.selectedTool,
                onShapeSelected: (final Tools tool) =>
                    appModel.selectedTool = tool,
                minimal: !appModel.isSidePanelExpanded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
