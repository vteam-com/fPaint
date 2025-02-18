import 'package:flutter/material.dart';
import 'package:fpaint/panels/layers/top_menu_and_layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The `SidePanel` widget is a stateful widget that represents the side panel of the application.
/// It uses the `MultiSplitView` widget to display the top menu and layers panel, as well as the tools panel.
/// The side panel is styled with a material elevation and a rounded border on the top-right and bottom-right corners.
/// The `MultiSplitViewTheme` is used to customize the appearance of the divider between the two panels.

class SidePanel extends StatefulWidget {
  const SidePanel({super.key});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  @override
  Widget build(BuildContext context) {
    final ShellProvider shellModel = ShellProvider.of(context);

    return Material(
      color: Colors.grey.shade800,
      child: MultiSplitViewTheme(
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
          axis: Axis.vertical,
          initialAreas: <Area>[
            Area(
              size: 400,
              min: 100,
              builder: (BuildContext context, Area area) =>
                  const TopMenuAndLayersPanel(),
            ),
            Area(
              size: 400,
              min: 100,
              builder: (BuildContext context, Area area) => Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ToolsPanel(
                  minimal: !shellModel.isSidePanelExpanded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
