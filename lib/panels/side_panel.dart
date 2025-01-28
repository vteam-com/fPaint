import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers/layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';

class SidePanel extends StatelessWidget {
  const SidePanel({super.key});

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
          spacing: 8,
          children: [
            //
            // Layers Panel
            //
            const Expanded(
              flex: 1,
              child: LayersPanel(),
            ),
            // Divider
            //
            const Divider(
              thickness: 1,
              height: 1,
              color: Colors.grey,
            ),

            //
            // Tools Panel
            //
            Expanded(
              flex: 2,
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
