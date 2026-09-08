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
  static const String rotateViewCounterClockwise = 'Rotate View Counter-Clockwise';
  static const String rotateViewClockwise = 'Rotate View Clockwise';
  static const String resetViewRotation = 'Reset View Rotation';
  static const String rotateViewTwist = 'Rotate View (any angle)';
  static const String rotateViewDrag = 'Rotate View';
  static const String twoFingerTwist = 'Two-finger twist';
  static const String rightDragSelection = 'Right-drag';
  static const String showKeyboardShortcutsSeparator = ', ';
  static const String brushTool = 'Brush Tool';
  static const String eraserTool = 'Eraser Tool';
  static const String selectionTool = 'Selection Tool';
  static const String fillTool = 'Fill Tool';
  static const String textTool = 'Text Tool';
  static const String addToSelection = 'Add to Selection';
  static const String subtractFromSelection = 'Subtract from Selection';
  static const String intersectWithSelection = 'Intersect with Selection';
  static const String wandSampleAllLayers = 'Edge Detection: Sample All Layers';
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
///
/// Apple platforms show the standard key glyphs (as printed on Apple keyboards);
/// other platforms spell the modifier out.
abstract class ShortcutModifiers {
  static const String cmd = '\u2318';
  static const String ctrl = 'Ctrl';
  static const String ctrlSymbol = '\u2303';
  static const String option = '\u2325';
  static const String alt = 'Alt';
  static const String shift = 'Shift';
  static const String shiftSymbol = '\u21E7';

  /// Separator placed between a modifier and the key it is combined with.
  static const String separator = ' + ';
}

/// Display strings for individual keyboard keys.
abstract class ShortcutKeys {
  static const String zero = '0';
  static const String f1 = 'F1';
  static const String slash = '/';
  static const String plus = '+';
  static const String minus = '-';
  static const String tab = 'Tab';
  static const String bracketLeft = '[';
  static const String bracketRight = ']';
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
