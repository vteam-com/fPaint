import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/quick_menu_geometry.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/quick_menu_model.dart';
import 'package:fpaint/models/quick_menu_slot.dart';
import 'package:fpaint/models/selector_mode_display.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_text.dart';
import 'package:fpaint/widgets/app_tooltip.dart';
import 'package:fpaint/widgets/toolbar_icon_button.dart';

/// Opacity of the dark disc behind the ring, matching the toolbar surfaces.
const double _discAlpha = 0.78;

/// Opacity of the disc's hairline rim.
const double _discRimAlpha = 0.35;

/// Opacity of the ring drawn around the slot a still-pressed pointer aims at.
const double _highlightRingAlpha = 0.9;

const double _slotSize = AppLayout.toolbarButtonSize;
const double _halfSlot = _slotSize / AppMath.two;
const double _halfSwatch = AppLayout.quickMenuSwatchSize / AppMath.two;
const double _halfPuck = AppLayout.quickMenuPuckSize / AppMath.two;
const double _halfDisc = AppLayout.quickMenuDiscSize / AppMath.two;

/// The on-canvas radial quick menu (Sketchbook "lagoon" / Krita pop-up
/// palette): recent tools plus Select and Undo on the ring, recent colors on
/// an inner arc, and a centre puck that scrubs brush size (and, for an armed
/// effect, strength). Select and Undo each fan out an outer sub-ring beside
/// themselves: the selection modes, or undo / redo.
///
/// It opens where the artist is working, so switching tool, color, or size
/// never takes eyes or hand off the stroke. Tapping anywhere else closes it.
class QuickMenu extends StatefulWidget {
  /// Creates the quick menu for [appProvider], sized by [interactionProfile].
  const QuickMenu({
    super.key,
    required this.appProvider,
    required this.interactionProfile,
  });

  /// Application state the menu reads and drives.
  final AppProvider appProvider;

  /// Button sizing for the current input modality.
  final InteractionLayoutProfile interactionProfile;

  @override
  State<QuickMenu> createState() => _QuickMenuState();
}

class _QuickMenuState extends State<QuickMenu> {
  /// Pointer travel since the current puck drag began.
  Offset _puckDrag = Offset.zero;

  /// Brush size when the current puck drag began.
  double _puckStartSize = AppDefaults.brushSize;

  /// Effect strength when the current puck drag began.
  double _puckStartStrength = AppEffects.defaultIntensity;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_model, _appProvider.toolOptionsRepaintListenable]),
      builder: (BuildContext _, Widget? _) {
        final Offset? anchor = _model.anchor;
        if (anchor == null) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) => _buildMenu(
            context.l10n,
            clampQuickMenuAnchor(anchor, constraints.biggest),
          ),
        );
      },
    );
  }

  AppProvider get _appProvider => widget.appProvider;

  /// The dark backdrop disc behind the ring; it never takes pointer input.
  Widget _buildDisc() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.overlayDark.withValues(alpha: _discAlpha),
          border: Border.all(
            color: AppColors.white.withValues(alpha: _discRimAlpha),
            width: AppStroke.thin,
          ),
        ),
      ),
    );
  }

  /// Lays out the whole menu around [center]: a tap-to-close barrier, the
  /// backdrop disc, the ring slots, the color arc, and the centre puck.
  Widget _buildMenu(AppLocalizations l10n, Offset center) {
    final List<QuickMenuSlot> slots = _appProvider.quickMenuSlots;
    final List<Color> colors = _appProvider.layers.recentColors.colors;

    return Stack(
      key: Keys.quickMenu,
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: Keys.quickMenuBarrier,
            behavior: HitTestBehavior.opaque,
            onTap: _model.close,
            onSecondaryTap: _model.close,
          ),
        ),
        _positioned(center, _halfDisc, _buildDisc()),
        for (int index = AppMath.zero; index < slots.length; index++)
          _positioned(
            quickMenuSlotCenter(center: center, index: index, count: slots.length),
            _halfSlot,
            _buildSlot(
              l10n,
              slots[index],
              key: ValueKey<String>('${Keys.quickMenuSlotKeyPrefixText}$index'),
              inSubmenu: false,
              isHighlighted: _model.highlightedSlot == index,
            ),
          ),
        ..._buildSubmenu(l10n, center, slots.length),
        for (int index = AppMath.zero; index < colors.length; index++)
          _positioned(
            quickMenuSlotCenter(
              center: center,
              index: index,
              count: colors.length,
              radius: AppLayout.quickMenuColorRadius,
            ),
            _halfSwatch,
            _buildSwatch(colors[index], index),
          ),
        _positioned(center, _halfPuck, _buildPuck(center)),
      ],
    );
  }

  /// The centre puck: drag sideways for brush size; with an effect armed,
  /// drag up or down for its strength.
  Widget _buildPuck(Offset center) {
    final bool canResize = _appProvider.canAdjustBrushSize;
    return AppTooltip(
      message: ShortcutActions.resizeBrushDrag,
      child: GestureDetector(
        key: Keys.quickMenuPuck,
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails _) {
          _puckStartSize = _appProvider.brushSize;
          _puckStartStrength = _appProvider.effectBrushModel.strength;
          _puckDrag = Offset.zero;
        },
        onPanUpdate: (DragUpdateDetails details) => _onPuckDrag(details.delta, center, canResize: canResize),
        onPanEnd: (DragEndDetails _) => _appProvider.hideDrawingToolPreview(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.overlayDark,
            border: Border.fromBorderSide(BorderSide(color: AppColors.white, width: AppStroke.thin)),
          ),
          child: Center(
            child: AppText(
              _appProvider.brushSize.round().toString(),
              variant: AppTextVariant.bodyBold,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// One slot: a tool, selection mode, or command, selected / enabled as the
  /// provider reports, and ringed while a still-pressed pointer aims at it.
  Widget _buildSlot(
    AppLocalizations l10n,
    QuickMenuSlot slot, {
    required Key key,
    required bool inSubmenu,
    bool isHighlighted = false,
  }) {
    final Widget button = buildToolbarIconButton(
      key: key,
      tooltip: _slotTooltip(l10n, slot),
      icon: _slotIcon(slot),
      interactionProfile: widget.interactionProfile,
      isSelected: _appProvider.isQuickMenuSlotSelected(slot, inSubmenu: inSubmenu),
      enabled: _appProvider.isQuickMenuSlotEnabled(slot, inSubmenu: inSubmenu),
      onPressed: () => _appProvider.pickQuickMenuSlot(slot),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Outer sub-ring slots sit outside the backdrop disc, so each carries
        // its own dark backing.
        color: inSubmenu ? AppColors.overlayDark.withValues(alpha: _discAlpha) : null,
        border: isHighlighted || inSubmenu
            ? Border.all(
                color: AppColors.white.withValues(alpha: isHighlighted ? _highlightRingAlpha : _discRimAlpha),
                width: isHighlighted ? AppStroke.emphasis : AppStroke.thin,
              )
            : null,
      ),
      child: Center(child: button),
    );
  }

  /// The expanded outer sub-ring (history or selection modes), fanned along
  /// the outer ring beside the inner slot that opened it; empty when none is.
  List<Widget> _buildSubmenu(AppLocalizations l10n, Offset center, int parentCount) {
    final QuickMenuSubmenu? submenu = _model.submenu;
    if (submenu == null) {
      return const <Widget>[];
    }
    final List<QuickMenuSlot> slots = _appProvider.quickMenuSubmenuSlots(submenu);
    final int parentIndex = _appProvider.quickMenuParentSlot(submenu);

    return <Widget>[
      for (int index = AppMath.zero; index < slots.length; index++)
        _positioned(
          quickMenuSubmenuSlotCenter(
            center: center,
            parentIndex: parentIndex,
            parentCount: parentCount,
            index: index,
            count: slots.length,
          ),
          _halfSlot,
          _buildSlot(
            l10n,
            slots[index],
            key: ValueKey<String>('${Keys.quickMenuSubmenuKeyPrefixText}$index'),
            inSubmenu: true,
          ),
        ),
    ];
  }

  /// One recent-color swatch: tapping it applies the color to whichever color
  /// the active tool paints with, then closes the menu.
  Widget _buildSwatch(Color color, int index) {
    return GestureDetector(
      key: ValueKey<String>('${Keys.quickMenuColorKeyPrefixText}$index'),
      onTap: () {
        _model.close();
        _appProvider.applyPaletteColor(color);
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: AppColors.white, width: AppStroke.thin),
        ),
      ),
    );
  }

  QuickMenuModel get _model => _appProvider.quickMenuModel;
  void _onPuckDrag(Offset delta, Offset center, {required bool canResize}) {
    _puckDrag += delta;
    if (canResize) {
      final double size = _appProvider.applyBrushSizeDrag(startSize: _puckStartSize, screenDx: _puckDrag.dx);
      _appProvider.showDrawingToolPreviewAt(size: size, position: center);
    }
    _appProvider.applyEffectStrengthDrag(startStrength: _puckStartStrength, screenDy: _puckDrag.dy);
  }

  /// Places [child] (a square of half-width [halfExtent]) centred on [point].
  Widget _positioned(Offset point, double halfExtent, Widget child) {
    return Positioned(
      left: point.dx - halfExtent,
      top: point.dy - halfExtent,
      width: halfExtent * AppMath.two,
      height: halfExtent * AppMath.two,
      child: child,
    );
  }

  /// The icon for [slot].
  static AppIcon _slotIcon(QuickMenuSlot slot) {
    final ToolDescriptor? tool = slot.tool;
    if (tool != null) {
      return tool.icon;
    }
    final SelectorMode? mode = slot.selectorMode;
    if (mode != null) {
      return mode.icon;
    }
    return switch (slot.command!) {
      QuickMenuCommand.selection => AppIcon.selector,
      QuickMenuCommand.undo => AppIcon.undo,
      QuickMenuCommand.redo => AppIcon.redo,
      QuickMenuCommand.selectAdd => AppIcon.selectorMathAdd,
      QuickMenuCommand.selectRemove => AppIcon.selectorMathRemove,
      QuickMenuCommand.invertSelection => AppIcon.selectorMathInvert,
      QuickMenuCommand.cancelSelection => AppIcon.selectorCancel,
    };
  }

  /// The tooltip for [slot], with its keyboard shortcut when it has one.
  static String? _slotTooltip(AppLocalizations l10n, QuickMenuSlot slot) {
    final ToolDescriptor? tool = slot.tool;
    if (tool != null) {
      return tooltipWithShortcut(tool.label(l10n), tool.shortcut);
    }
    final SelectorMode? mode = slot.selectorMode;
    if (mode != null) {
      return mode.label(l10n);
    }
    return switch (slot.command!) {
      QuickMenuCommand.selection => tooltipWithShortcut(l10n.toolSelector, singleKeyShortcut(ShortcutKeys.s)),
      QuickMenuCommand.undo => tooltipWithShortcut(ShortcutActions.undo, primaryModifiedShortcut(ShortcutKeys.z)),
      QuickMenuCommand.redo => tooltipWithShortcut(ShortcutActions.redo, primaryModifiedShortcut(ShortcutKeys.y)),
      QuickMenuCommand.selectAdd => tooltipWithShortcut(l10n.toolAdd, shiftModifierShortcutLabel()),
      QuickMenuCommand.selectRemove => tooltipWithShortcut(l10n.toolRemove, secondaryModifierShortcutLabel()),
      QuickMenuCommand.invertSelection => l10n.toolInvert,
      QuickMenuCommand.cancelSelection => tooltipWithShortcut(l10n.cancel, singleKeyShortcut(ShortcutKeys.escape)),
    };
  }
}
