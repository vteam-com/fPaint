import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/panels/layers/layer_selector.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/side_panel_header.dart';

/// A widget that displays the layers panel in the top split of the side panel.
class TopMenuAndLayersPanel extends StatelessWidget {
  const TopMenuAndLayersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ShellProvider shellProvider = ShellProvider.of(context);
    final LayersProvider layers = LayersProvider.of(context);
    final AppLocalizations l10n = context.l10n;

    return ListenableBuilder(
      listenable: shellProvider.sidePanelExpandedListenable,
      builder: (BuildContext _, Widget? _) {
        return Column(
          children: <Widget>[
            SidePanelHeader(
              title: l10n.sidePanelLayersSection,
              trailing: const _LayersHeaderActions(),
            ),
            ListenableBuilder(
              listenable: layers.layerListStructureListenable,
              builder: (BuildContext context2, Widget? _) {
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

  /// The selected index last revealed, so unrelated layer notifications
  /// (thumbnails, opacity, …) never move the list.
  int? _revealedIndex;

  /// Scrolls the list to keep the selected layer in view.
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.layers.thumbnailsVisible = true;
    widget.layers.addListener(_onLayersChanged);
    // Reveal the initial selection too, e.g. a reopened file's remembered layer.
    _onLayersChanged();
  }

  @override
  void dispose() {
    widget.layers.removeListener(_onLayersChanged);
    widget.layers.thumbnailsVisible = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReorderableLayerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layers, widget.layers)) {
      oldWidget.layers.removeListener(_onLayersChanged);
      widget.layers.addListener(_onLayersChanged);
      _revealedIndex = null;
      _onLayersChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.layers.length,
      itemBuilder: (BuildContext _, int index) {
        final LayerProvider layer = widget.layers.get(index);
        final Widget child = ListenableBuilder(
          listenable: layer,
          builder: (BuildContext _, Widget? _) {
            return GestureDetector(
              onTap: () => widget.layers.selectedLayerIndex = index,
              onDoubleTap: () => widget.layers.layersToggleVisibility(layer),
              child: LayerSelector(
                context: widget.parentContext,
                layers: widget.layers,
                layer: layer,
                minimal: !widget.shellProvider.isSidePanelExpanded,
                isSelected: layer.isSelected,
                allowRemoveLayer: index != widget.layers.length - 1,
              ),
            );
          },
        );

        final Widget dropTarget = KeyedSubtree(
          key: _rowKeyFor(layer),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (DragTargetDetails<int> details) => details.data != index,
            onAcceptWithDetails: (DragTargetDetails<int> details) {
              final int oldIndex = details.data;
              final int newIndex = index;
              widget.layers.reorderLayer(fromIndex: oldIndex, toIndex: newIndex);
            },
            builder: (BuildContext _, List<int?> _, List<dynamic> _) {
              return Opacity(
                opacity: _draggedIndex == index ? AppVisual.low : AppVisual.full,
                child: child,
              );
            },
          ),
        );

        if (_useImmediateDrag) {
          return Draggable<int>(
            key: Key('$index'),
            data: index,
            feedback: Opacity(opacity: AppVisual.medium, child: child),
            childWhenDragging: Opacity(opacity: AppVisual.low, child: child),
            onDragStarted: () => setState(() => _draggedIndex = index),
            onDragEnd: (_) => setState(() => _draggedIndex = null),
            child: dropTarget,
          );
        }

        return LongPressDraggable<int>(
          key: Key('$index'),
          data: index,
          feedback: Opacity(opacity: AppVisual.medium, child: child),
          childWhenDragging: Opacity(opacity: AppVisual.low, child: child),
          onDragStarted: () => setState(() => _draggedIndex = index),
          onDragEnd: (_) => setState(() => _draggedIndex = null),
          child: dropTarget,
        );
      },
    );
  }

  /// Schedules a reveal when the selected layer changed, from any source: the
  /// on-canvas layer picker, a new layer, undo, or a panel tap.
  void _onLayersChanged() {
    final int selectedIndex = widget.layers.selectedLayerIndex;
    if (selectedIndex == _revealedIndex) {
      return;
    }
    _revealedIndex = selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _revealSelectedLayer(jumpsLeft: AppInteraction.layerRevealMaxJumps),
    );
  }

  /// Scrolls just enough to bring the selected layer's row fully into view,
  /// leaving the list alone when it already is.
  ///
  /// The lazy list only builds rows near the viewport, and rows vary in
  /// height, so an unbuilt row is approached by jumping to its proportional
  /// offset and retrying once that frame has built it.
  Future<void> _revealSelectedLayer({required int jumpsLeft}) async {
    if (!mounted || !_scrollController.hasClients || !widget.layers.isIndexInRange(widget.layers.selectedLayerIndex)) {
      return;
    }

    final int index = widget.layers.selectedLayerIndex;
    final BuildContext? row = _rowKeyFor(widget.layers.get(index)).currentContext;
    if (row != null) {
      // Each policy is a no-op unless the row overflows its edge, so applying
      // both scrolls only in the direction the row is clipped.
      for (final ScrollPositionAlignmentPolicy policy in const <ScrollPositionAlignmentPolicy>[
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        if (!row.mounted) {
          return;
        }
        await Scrollable.ensureVisible(
          row,
          alignmentPolicy: policy,
          duration: AppDefaults.layerRevealScrollDuration,
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (jumpsLeft <= 0) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    final double contentExtent = position.maxScrollExtent + position.viewportDimension;
    final double estimate = contentExtent * index / widget.layers.length;
    _scrollController.jumpTo(estimate.clamp(position.minScrollExtent, position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _revealSelectedLayer(jumpsLeft: jumpsLeft - 1),
    );
  }

  /// The key locating [layer]'s row, by layer identity so it follows reorders.
  GlobalObjectKey _rowKeyFor(LayerProvider layer) => GlobalObjectKey(layer);
  bool get _useImmediateDrag {
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }
}

/// Layers header actions: the "All layers" scope toggle beside the
/// pick-layer button.
class _LayersHeaderActions extends StatelessWidget {
  const _LayersHeaderActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _AllLayersToggle(),
        _LayerPickerToggle(),
      ],
    );
  }
}

/// Sticky "All layers" scope toggle: when on, the wand samples the merged
/// composite, transform/cut/copy act on every visible, unlocked layer, and
/// the eraser erases them all.
class _AllLayersToggle extends StatelessWidget {
  const _AllLayersToggle();

  @override
  Widget build(BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);
    final AppLocalizations l10n = context.l10n;

    return ListenableBuilder(
      listenable: appProvider.toolOptionsRepaintListenable,
      builder: (BuildContext _, Widget? _) {
        final bool isOn = appProvider.selectorModel.allLayers;
        return AppButtonIcon(
          key: Keys.layersAllLayersToggleButton,
          tooltip: tooltipWithShortcut(l10n.selectionAllLayers, primaryModifierShortcutLabel()),
          icon: AppIcon.layers,
          isSelected: isOn,
          onPressed: () => appProvider.setSelectorAllLayers(!isOn),
        );
      },
    );
  }
}

/// Header toggle that arms the single-shot pick-layer mode.
///
/// The Shift+Alt click chord covers keyboard-equipped desktops; this button is
/// how pen and touch reach the same gesture. Arming it drops the on-canvas
/// [LayerPickerPuck], which commits on release and disarms itself.
class _LayerPickerToggle extends StatelessWidget {
  const _LayerPickerToggle();

  @override
  Widget build(BuildContext context) {
    final AppProvider appProvider = AppProvider.of(context);
    final AppLocalizations l10n = context.l10n;

    return ListenableBuilder(
      listenable: appProvider.toolOptionsRepaintListenable,
      builder: (BuildContext _, Widget? _) {
        final bool isArmed = appProvider.layerPickerPosition != null;
        return AppButtonIcon(
          key: Keys.layerPickerToggleButton,
          // The chord needs a canvas click to commit, so the gesture is named
          // alongside the keys: the modifiers alone pick nothing.
          tooltip: tooltipWithShortcut(
            l10n.layerPickerTooltip,
            shortcutCombination(<String>[
              shiftModifierShortcutLabel(),
              secondaryModifierShortcutLabel(),
              ShortcutActions.clickCanvas,
            ]),
          ),
          icon: AppIcon.eyedropper,
          isSelected: isArmed,
          onPressed: () {
            if (isArmed) {
              appProvider.disarmLayerPicker();
            } else {
              appProvider.armLayerPicker();
            }
          },
        );
      },
    );
  }
}
