import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/quick_menu_slot.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';

/// Tools the quick menu offers before the artist has used any.
const List<ToolDescriptor> _defaultRecentTools = <ToolDescriptor>[
  ToolDescriptor.gesture(ToolKind.brush),
  ToolDescriptor.gesture(ToolKind.eraser),
  ToolDescriptor.gesture(ToolKind.smudge),
  ToolDescriptor.gesture(ToolKind.pencil),
  ToolDescriptor.gesture(ToolKind.fill),
  ToolDescriptor.gesture(ToolKind.line),
];

/// State of the on-canvas quick menu: where it is open, which ring slot a
/// still-pressed opening pointer points at, and the recently used tools it
/// offers. Which pointer is tracking is the gesture handler's business.
class QuickMenuModel extends ChangeNotifier {
  /// Screen-space centre of the open menu; null while the menu is closed.
  Offset? _anchor;

  /// Ring slot under a still-pressed opening pointer, or null for none.
  int? _highlightedSlot;

  List<ToolDescriptor> _recentTools = List<ToolDescriptor>.of(_defaultRecentTools);

  /// The outer sub-ring currently expanded, or null for none.
  QuickMenuSubmenu? _submenu;

  /// Screen-space centre of the open menu; null while the menu is closed.
  Offset? get anchor => _anchor;

  /// Ring slot under a still-pressed opening pointer, or null for none.
  int? get highlightedSlot => _highlightedSlot;

  /// Whether the menu is showing.
  bool get isOpen => _anchor != null;

  /// The outer sub-ring currently expanded, or null for none.
  QuickMenuSubmenu? get submenu => _submenu;

  /// Most recently used tools first, capped at [AppLimits.quickMenuRecentToolCount].
  List<ToolDescriptor> get recentTools => List<ToolDescriptor>.unmodifiable(_recentTools);

  /// Closes the menu.
  void close() {
    if (!isOpen) {
      return;
    }
    _anchor = null;
    _highlightedSlot = null;
    _submenu = null;
    notifyListeners();
  }

  /// Stops following the opening pointer, leaving the menu open for taps.
  void endTracking() {
    highlightedSlot = null;
  }

  /// Expands [submenu] as the outer sub-ring, replacing any other.
  void expand(QuickMenuSubmenu submenu) {
    if (_submenu == submenu) {
      return;
    }
    _submenu = submenu;
    notifyListeners();
  }

  /// Opens the menu centred on [anchor], with no sub-ring expanded.
  void open(Offset anchor) {
    _anchor = anchor;
    _highlightedSlot = null;
    _submenu = null;
    notifyListeners();
  }

  /// Expands [submenu], or collapses it when it is already the open one.
  void toggle(QuickMenuSubmenu submenu) {
    if (_submenu == submenu) {
      _submenu = null;
      notifyListeners();
      return;
    }
    expand(submenu);
  }

  /// Promotes [tool] to the front of the recent tools.
  void recordTool(ToolDescriptor tool) {
    _recentTools = <ToolDescriptor>[
      tool,
      ..._recentTools.where((ToolDescriptor recentTool) => recentTool != tool),
    ].take(AppLimits.quickMenuRecentToolCount).toList();
  }

  /// Highlights the ring slot under the still-pressed opening pointer.
  set highlightedSlot(int? slot) {
    if (slot == _highlightedSlot) {
      return;
    }
    _highlightedSlot = slot;
    notifyListeners();
  }
}
