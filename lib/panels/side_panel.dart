import 'package:flutter/material.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/models/app_model.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';

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
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        clipBehavior: Clip.none,
        child: Column(
          children: [
            //
            // Layers Panel
            //
            Expanded(
              child: LayersPanel(
                selectedLayerIndex: appModel.selectedLayerIndex,
                onSelectLayer: (final int layerIndex) =>
                    appModel.selectedLayerIndex = layerIndex,
                onAddLayer: () => _onAddLayer(context),
                onFileOpen: () async => await onFileOpen(context),
                onRemoveLayer: (final int indexToRemove) =>
                    AppModel.get(context).removeLayer(indexToRemove),
              ),
            ),
            //
            // Divider
            //
            const Divider(
              thickness: 8,
              height: 16,
              color: Colors.grey,
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

  // Method to add a new layer
  void _onAddLayer(final BuildContext context) {
    final AppModel appModel = AppModel.get(context);
    final Layer newLayer = appModel.addLayerTop();

    appModel.selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
  }
}
