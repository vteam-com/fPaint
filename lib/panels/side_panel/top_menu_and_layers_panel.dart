import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/panels/side_panel/side_panel_top_menu.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:provider/provider.dart';

/// A widget that displays the top menu and layers panel.
class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context, listen: true);

    return Column(
      children: <Widget>[
        // toolbar
        SidePanelTopMenu(shellProvider: shellProvider),

        Consumer<LayersProvider>(
          builder:
              (
                final BuildContext context2,
                final LayersProvider layers,
                final Widget? _,
              ) {
                return Expanded(
                  child: _ReorderableLayerList(
                    layers: layers,
                    shellProvider: shellProvider,
                    parentContext: context2,
                  ),
                );
              },
        ),
      ],
    );
  }
}

/// A drag-to-reorder list for layers, replacing Material [ReorderableListView].
class _ReorderableLayerList extends StatefulWidget {
  const _ReorderableLayerList({
    required this.layers,
    required this.shellProvider,
    required this.parentContext,
  });
  final LayersProvider layers;
  final BuildContext parentContext;
  final ShellProvider shellProvider;
  @override
  State<_ReorderableLayerList> createState() => _ReorderableLayerListState();
}

class _ReorderableLayerListState extends State<_ReorderableLayerList> {
  int? _draggedIndex;

  @override
  Widget build(final BuildContext context) {
    return ListView.builder(
      itemCount: widget.layers.length,
      itemBuilder: (final BuildContext _, final int index) {
        final LayerProvider layer = widget.layers.get(index);
        final Widget child = GestureDetector(
          onTap: () => widget.layers.selectedLayerIndex = index,
          onDoubleTap: () => widget.layers.layersToggleVisibility(layer),
          child: LayerSelector(
            context: widget.parentContext,
            layer: layer,
            minimal: !widget.shellProvider.isSidePanelExpanded,
            isSelected: widget.layers.selectedLayerIndex == index,
            allowRemoveLayer: index != widget.layers.length - 1,
          ),
        );

        return LongPressDraggable<int>(
          key: Key('$index'),
          data: index,
          feedback: Opacity(opacity: AppVisual.medium, child: child),
          childWhenDragging: Opacity(opacity: AppVisual.low, child: child),
          onDragStarted: () => setState(() => _draggedIndex = index),
          onDragEnd: (final _) => setState(() => _draggedIndex = null),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (final DragTargetDetails<int> details) => details.data != index,
            onAcceptWithDetails: (final DragTargetDetails<int> details) {
              final int oldIndex = details.data;
              final int newIndex = index;
              final int adjustedIndex = newIndex > oldIndex ? newIndex : newIndex;
              final LayerProvider movedLayer = widget.layers.get(oldIndex);
              widget.layers.removeByIndex(oldIndex);
              widget.layers.insert(adjustedIndex, movedLayer);
              widget.layers.selectedLayerIndex = adjustedIndex;
            },
            builder: (final BuildContext _, final List<int?> _, final List<dynamic> _) {
              return Opacity(
                opacity: _draggedIndex == index ? AppVisual.low : AppVisual.full,
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}
