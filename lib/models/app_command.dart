import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/tool_kind.dart';

/// Shell commands surfaced from more than one place (top toolbar, main menu,
/// on-canvas quick menu).
///
/// Each command owns its icon and keyboard shortcut once, so every surface
/// shows the same glyph and advertises the same binding. Labels stay at the
/// call site because surfaces word them differently (e.g. a toolbar tooltip vs.
/// a menu entry, or undo's history-aware label).
enum AppCommand {
  /// Starts a new document.
  newDocument(AppIcon.powerSettingsNew),

  /// Opens the import sheet.
  importFile(AppIcon.fileDownload),

  /// Opens the export / share panel.
  exportFile(AppIcon.iosShare),

  /// Pastes the clipboard.
  paste(AppIcon.clipboardPaste),

  /// Undoes the last action.
  undo(AppIcon.undo),

  /// Redoes the last undone action.
  redo(AppIcon.redo),

  /// Arms the selection tool.
  selector(AppIcon.selector),

  /// Zooms the canvas in.
  zoomIn(AppIcon.zoomIn),

  /// Zooms the canvas out.
  zoomOut(AppIcon.zoomOut);

  const AppCommand(this.icon);

  /// Icon shown for this command on every surface.
  final AppIcon icon;

  /// Display label of the keyboard shortcut bound to this command, or null
  /// when the command has no binding.
  String? get shortcut {
    return switch (this) {
      AppCommand.paste => primaryModifiedShortcut(ShortcutKeys.v),
      AppCommand.undo => primaryModifiedShortcut(ShortcutKeys.z),
      AppCommand.redo => primaryModifiedShortcut(ShortcutKeys.y),
      AppCommand.zoomIn => primaryModifiedShortcut(ShortcutKeys.plus),
      AppCommand.zoomOut => primaryModifiedShortcut(ShortcutKeys.minus),
      AppCommand.selector => toolShortcutLabel(ToolKind.selector),
      AppCommand.newDocument || AppCommand.importFile || AppCommand.exportFile => null,
    };
  }

  /// [label] followed by this command's shortcut, when it has one.
  String tooltip(String label) => tooltipWithShortcut(label, shortcut)!;
}
