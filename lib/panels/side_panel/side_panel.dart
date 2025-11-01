import 'package:flutter/material.dart';
import 'package:fpaint/panels/side_panel/top_menu_and_layers_panel.dart';
import 'package:fpaint/panels/tools/tools_panel.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:multi_split_view/multi_split_view.dart';

/// The `SidePanel` widget is a stateful widget that represents the side panel of the application.
/// It uses the `MultiSplitView` widget to display the top menu and layers panel, as well as the tools panel.
/// The side panel is styled with a material elevation and a rounded border on the top-right and bottom-right corners.
/// The `MultiSplitViewTheme` is used to customize the appearance of the divider between the two panels.
class SidePanel extends StatefulWidget {
  const SidePanel({
    super.key,
    required this.minimal,
    required this.preferences,
  });

  /// A boolean indicating whether the side panel should be displayed in minimal mode.
  final bool minimal;

  /// The app preferences.
  final AppPreferences preferences;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  final MultiSplitViewController _splitController = MultiSplitViewController();

  @override
  void initState() {
    super.initState();

    final double topPanelHeight = widget.preferences.sidePanelDistance;

    _splitController.areas = <Area>[
      Area(
        size: topPanelHeight,
        min: 100,
        builder: (final BuildContext context, final Area area) => const TopMenuAndLayersPanel(),
      ),
      Area(
        min: 100,
        builder: (final BuildContext context, final Area area) => Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: ToolsPanel(
            minimal: widget.minimal,
          ),
        ),
      ),
    ];

    // start listening to user change
    _splitController.addListener(_rebuild);
  }

  @override
  void dispose() {
    super.dispose();
    _splitController.removeListener(_rebuild);
  }

  @override
  Widget build(final BuildContext context) {
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
          controller: _splitController,
          axis: Axis.vertical,
        ),
      ),
    );
  }

  /// Rebuilds the widget when the split controller changes.
  void _rebuild() async {
    final double? heightOfTopSection = _splitController.areas[0].size;
    if (heightOfTopSection != null) {
      await widget.preferences.setSidePanelDistance(heightOfTopSection);
    }
  }
}
