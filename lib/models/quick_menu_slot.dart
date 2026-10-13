import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/tool_descriptor.dart';

/// Commands on the quick menu. [selection] and [undo] sit on the inner ring
/// and each opens its outer sub-ring; [redo] lives only on the history ring,
/// and the selection math / invert / cancel commands on the selection ring.
enum QuickMenuCommand {
  selection,
  undo,
  redo,
  selectAdd,
  selectRemove,
  invertSelection,
  cancelSelection,
}

/// The outer sub-ring a quick menu command expands.
enum QuickMenuSubmenu {
  /// Undo / redo, opened by the Undo slot.
  history,

  /// The selection modes, then add / remove / invert / cancel, opened by the
  /// Select slot.
  selection,
}

/// One quick menu slot: a tool to activate, a selection mode to switch to, or
/// a command.
class QuickMenuSlot {
  /// Creates a slot that activates [tool].
  const QuickMenuSlot.tool(ToolDescriptor this.tool) : command = null, selectorMode = null;

  /// Creates a slot that runs [command].
  const QuickMenuSlot.command(QuickMenuCommand this.command) : tool = null, selectorMode = null;

  /// Creates a slot that switches to the selection tool in [selectorMode].
  const QuickMenuSlot.selectorMode(SelectorMode this.selectorMode) : tool = null, command = null;

  /// The command this slot runs; null for a tool or selection-mode slot.
  final QuickMenuCommand? command;

  /// The selection mode this slot switches to; null for the other kinds.
  final SelectorMode? selectorMode;

  /// The tool this slot activates; null for the other kinds.
  final ToolDescriptor? tool;
}
