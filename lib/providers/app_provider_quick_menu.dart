part of 'app_provider.dart';

/// Tools that belong on the quick menu ring: every rail tool, no selector.
final Set<ToolDescriptor> _quickMenuEligibleTools = <ToolDescriptor>{
  ...brushSectionTools(),
  ...elementSectionTools(),
};

/// Shared tool activation and the on-canvas quick menu.
extension AppProviderQuickMenu on AppProvider {
  /// The single active tool: the armed effect brush, else the gesture tool.
  ToolDescriptor get activeTool {
    final SelectionEffect? armedEffect = effectBrushModel.effect;
    return armedEffect != null ? ToolDescriptor.adjust(armedEffect) : ToolDescriptor.gesture(selectedAction);
  }

  /// Makes [tool] the active tool: arms an effect, or selects a gesture tool
  /// (which disarms any effect), keeping exactly one tool active.
  void activateTool(ToolDescriptor tool) {
    final SelectionEffect? effect = tool.effect;
    if (effect != null) {
      if (effectBrushModel.effect != effect) {
        armEffectBrush(effect);
      }
      return;
    }
    selectedAction = tool.action!;
  }

  /// Applies a palette [color] to whichever color the active tool paints with:
  /// the fill color for shapes and the paint bucket, else the brush color.
  void applyPaletteColor(Color color) {
    if (selectedAction == ActionType.rectangle ||
        selectedAction == ActionType.circle ||
        selectedAction == ActionType.fill) {
      fillColor = color;
    } else {
      brushColor = color;
    }
  }

  /// The inner ring slots, clockwise from the top: the recent tools, then
  /// Select and Undo (each of which expands an outer sub-ring).
  List<QuickMenuSlot> get quickMenuSlots => <QuickMenuSlot>[
    for (final ToolDescriptor tool in quickMenuModel.recentTools) QuickMenuSlot.tool(tool),
    const QuickMenuSlot.command(QuickMenuCommand.selection),
    const QuickMenuSlot.command(QuickMenuCommand.undo),
  ];

  /// The slots of the outer sub-ring for [submenu].
  List<QuickMenuSlot> quickMenuSubmenuSlots(QuickMenuSubmenu submenu) => switch (submenu) {
    QuickMenuSubmenu.history => const <QuickMenuSlot>[
      QuickMenuSlot.command(QuickMenuCommand.undo),
      QuickMenuSlot.command(QuickMenuCommand.redo),
    ],
    QuickMenuSubmenu.selection => <QuickMenuSlot>[
      for (final SelectorMode mode in SelectorMode.values) QuickMenuSlot.selectorMode(mode),
      const QuickMenuSlot.command(QuickMenuCommand.selectAdd),
      const QuickMenuSlot.command(QuickMenuCommand.selectRemove),
      const QuickMenuSlot.command(QuickMenuCommand.invertSelection),
      const QuickMenuSlot.command(QuickMenuCommand.cancelSelection),
    ],
  };

  /// Index on the inner ring of the slot that expands [submenu]; its sub-ring
  /// fans out beside it.
  int quickMenuParentSlot(QuickMenuSubmenu submenu) {
    final QuickMenuCommand parent = switch (submenu) {
      QuickMenuSubmenu.history => QuickMenuCommand.undo,
      QuickMenuSubmenu.selection => QuickMenuCommand.selection,
    };
    return quickMenuSlots.indexWhere((QuickMenuSlot slot) => slot.command == parent);
  }

  /// Whether [slot] can be used now. On the inner ring Undo stays usable while
  /// only redo is possible, since it is the way into the history ring. The
  /// selection math and Invert need a selection to work on; Cancel also backs
  /// out of an armed selector with no marquee yet.
  bool isQuickMenuSlotEnabled(QuickMenuSlot slot, {required bool inSubmenu}) {
    return switch (slot.command) {
      QuickMenuCommand.undo => undoProvider.canUndo || (!inSubmenu && undoProvider.canRedo),
      QuickMenuCommand.redo => undoProvider.canRedo,
      QuickMenuCommand.selectAdd ||
      QuickMenuCommand.selectRemove ||
      QuickMenuCommand.invertSelection => selectorModel.isVisible,
      QuickMenuCommand.cancelSelection => selectorModel.isVisible || selectedAction == ActionType.selector,
      QuickMenuCommand.selection || null => true,
    };
  }

  /// Whether [slot] shows as selected: the active tool or selection mode, or
  /// the command whose sub-ring is expanded.
  bool isQuickMenuSlotSelected(QuickMenuSlot slot, {required bool inSubmenu}) {
    final ToolDescriptor? tool = slot.tool;
    if (tool != null) {
      return tool == activeTool;
    }
    final SelectorMode? mode = slot.selectorMode;
    if (mode != null) {
      return selectedAction == ActionType.selector && selectorModel.mode == mode;
    }
    return switch (slot.command!) {
      QuickMenuCommand.selection =>
        selectedAction == ActionType.selector || quickMenuModel.submenu == QuickMenuSubmenu.selection,
      QuickMenuCommand.undo => !inSubmenu && quickMenuModel.submenu == QuickMenuSubmenu.history,
      QuickMenuCommand.selectAdd => selectorModel.math == SelectorMath.add,
      QuickMenuCommand.selectRemove => selectorModel.math == SelectorMath.remove,
      QuickMenuCommand.redo || QuickMenuCommand.invertSelection || QuickMenuCommand.cancelSelection => false,
    };
  }

  /// Opens the quick menu at [screenPosition], first recording the active
  /// tool so the ring leads with what the artist was just using.
  void openQuickMenu(Offset screenPosition) {
    hideDrawingToolPreview();
    _recordQuickMenuTool(activeTool);
    quickMenuModel.open(screenPosition);
  }

  /// Runs [slot]. A tool or selection mode is applied and closes the menu;
  /// Select toggles the selection sub-ring; Undo / Redo step the history and
  /// keep the history ring open so the artist can keep stepping. Add / Remove
  /// are toggles that keep the selection ring open (pick a mode next); Invert
  /// and Cancel act on the selection and close the menu.
  void pickQuickMenuSlot(QuickMenuSlot slot) {
    final ToolDescriptor? tool = slot.tool;
    if (tool != null) {
      quickMenuModel.close();
      activateTool(tool);
      _recordQuickMenuTool(tool);
      return;
    }
    final SelectorMode? mode = slot.selectorMode;
    if (mode != null) {
      quickMenuModel.close();
      activateSelectorMode(mode);
      return;
    }
    switch (slot.command!) {
      case QuickMenuCommand.selection:
        quickMenuModel.toggle(QuickMenuSubmenu.selection);
      case QuickMenuCommand.undo:
        quickMenuModel.expand(QuickMenuSubmenu.history);
        if (undoProvider.canUndo) {
          unawaited(undoAction());
        }
      case QuickMenuCommand.redo:
        quickMenuModel.expand(QuickMenuSubmenu.history);
        if (undoProvider.canRedo) {
          unawaited(redoAction());
        }
      case QuickMenuCommand.selectAdd:
        toggleSelectorMath(SelectorMath.add);
      case QuickMenuCommand.selectRemove:
        toggleSelectorMath(SelectorMath.remove);
      case QuickMenuCommand.invertSelection:
        quickMenuModel.close();
        invertSelection();
      case QuickMenuCommand.cancelSelection:
        quickMenuModel.close();
        clearSelectionAndRestorePreviousTool();
    }
  }

  /// Sets the armed effect's strength from a vertical puck drag of [screenDy]
  /// pixels since [startStrength]; dragging up strengthens.
  void applyEffectStrengthDrag({required double startStrength, required double screenDy}) {
    final SelectionEffect? effect = effectBrushModel.effect;
    if (effect == null) {
      return;
    }
    final double minStrength = effect.bipolar ? -AppEffects.maxIntensity : AppEffects.minIntensity;
    final double strength = startStrength - screenDy / AppInteraction.quickMenuStrengthDragPixelsPerUnit;
    setEffectBrushStrength(strength.clamp(minStrength, AppEffects.maxIntensity));
  }

  void _recordQuickMenuTool(ToolDescriptor tool) {
    if (_quickMenuEligibleTools.contains(tool)) {
      quickMenuModel.recordTool(tool);
    }
  }
}
