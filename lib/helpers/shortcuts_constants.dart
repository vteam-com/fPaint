// ignore: fcheck_one_class_per_file
/// Centralized constants for keyboard shortcuts and their display text.
abstract class ShortcutCategories {
  static const String fileOperations = 'File Operations';
  static const String editing = 'Editing';
  static const String view = 'View';
  static const String tools = 'Tools';
  static const String layers = 'Layers';
  static const String selection = 'Selection';
}

/// Display strings for keyboard shortcut actions.
abstract class ShortcutActions {
  static const String save = 'Save';
  static const String open = 'Open';
  static const String newCanvas = 'New Canvas';
  static const String undo = 'Undo';
  static const String redo = 'Redo';
  static const String cut = 'Cut';
  static const String copy = 'Copy';
  static const String paste = 'Paste';
  static const String duplicateSameLayer = 'Duplicate in Same Layer';
  static const String duplicateNewLayer = 'Duplicate on New Layer';
  static const String dragSelection = 'Drag Selection';
  static const String zoomIn = 'Zoom In';
  static const String zoomOut = 'Zoom Out';
  static const String resetZoom = 'Reset Zoom';
  static const String showKeyboardShortcuts = 'Ctrl /, F1';
  static const String brushTool = 'Brush Tool';
  static const String eraserTool = 'Eraser Tool';
  static const String selectionTool = 'Selection Tool';
  static const String fillTool = 'Fill Tool';
  static const String textTool = 'Text Tool';
  static const String addToSelection = 'Add to Selection';
  static const String subtractFromSelection = 'Subtract from Selection';
  static const String intersectWithSelection = 'Intersect with Selection';
  static const String wandSampleAllLayers = 'Magic Wand: Sample All Layers';
  static const String floodFillSampleAllLayers = 'Flood Fill: Sample All Layers';
  static const String newLayer = 'New Layer';
  static const String deleteLayer = 'Delete Layer';
}

/// Display strings for UI control labels related to shortcuts.
abstract class ShortcutLabels {
  static const String delete = 'Delete';
  static const String close = 'Close';
}

/// Internal map keys used by shortcut-row metadata.
abstract class ShortcutMapKeys {
  static const String keys = 'keys';
  static const String description = 'description';
}

/// Display strings for keyboard modifier keys.
abstract class ShortcutModifiers {
  static const String cmd = 'Cmd';
  static const String ctrl = 'Ctrl';
  static const String option = 'Option';
  static const String alt = 'Alt';
  static const String shift = 'Shift';
}

/// Display strings for individual keyboard keys.
abstract class ShortcutKeys {
  static const String tab = 'Tab';
  static const String b = 'B';
  static const String c = 'C';
  static const String d = 'D';
  static const String e = 'E';
  static const String f = 'F';
  static const String n = 'N';
  static const String o = 'O';
  static const String s = 'S';
  static const String t = 'T';
  static const String v = 'V';
  static const String x = 'X';
  static const String y = 'Y';
  static const String z = 'Z';
}
