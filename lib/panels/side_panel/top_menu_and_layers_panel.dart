import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';

/// A widget that displays the layers panel in the top split of the side panel.
class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(final BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context);
    final LayersProvider layers = LayersProvider.of(context);

    return ListenableBuilder(
      listenable: shellProvider.sidePanelExpandedListenable,
      builder: (final BuildContext _, final Widget? _) {
        return Column(
          children: <Widget>[
            ListenableBuilder(
              listenable: layers.layerListStructureListenable,
              builder: (final BuildContext context2, final Widget? _) {
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
      },
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
        final Widget child = ListenableBuilder(
          listenable: layer,
          builder: (final BuildContext _, final Widget? _) {
            return GestureDetector(
              onTap: () => widget.layers.selectedLayerIndex = index,
              onDoubleTap: () => widget.layers.layersToggleVisibility(layer),
              child: LayerSelector(
                context: widget.parentContext,
                layer: layer,
                minimal: !widget.shellProvider.isSidePanelExpanded,
                isSelected: layer.isSelected,
                allowRemoveLayer: index != widget.layers.length - 1,
              ),
            );
          },
        );

        final Widget dropTarget = DragTarget<int>(
          onWillAcceptWithDetails: (final DragTargetDetails<int> details) => details.data != index,
          onAcceptWithDetails: (final DragTargetDetails<int> details) {
            final int oldIndex = details.data;
            final int newIndex = index;
            widget.layers.reorderLayer(fromIndex: oldIndex, toIndex: newIndex);
          },
          builder: (final BuildContext _, final List<int?> _, final List<dynamic> _) {
            return Opacity(
              opacity: _draggedIndex == index ? AppVisual.low : AppVisual.full,
              child: child,
            );
          },
        );

        if (_useImmediateDrag) {
          return Draggable<int>(
            key: Key('$index'),
            data: index,
            feedback: Opacity(opacity: AppVisual.medium, child: child),
            childWhenDragging: Opacity(opacity: AppVisual.low, child: child),
            onDragStarted: () => setState(() => _draggedIndex = index),
            onDragEnd: (final _) => setState(() => _draggedIndex = null),
            child: dropTarget,
          );
        }

        return LongPressDraggable<int>(
          key: Key('$index'),
          data: index,
          feedback: Opacity(opacity: AppVisual.medium, child: child),
          childWhenDragging: Opacity(opacity: AppVisual.low, child: child),
          onDragStarted: () => setState(() => _draggedIndex = index),
          onDragEnd: (final _) => setState(() => _draggedIndex = null),
          child: dropTarget,
        );
      },
    );
  }

  bool get _useImmediateDrag {
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }
}
