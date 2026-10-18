import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Options a tool exposes in its tool-options panel.
enum ActionOptions {
  brushSize,
  brushIntensity,
  brushStyle,
  brushColor,
  colorFill,
  tolerance,
  topColors,
  selectorOptions,
}

/// How a tool turns canvas pointer input into edits.
///
/// The canvas gesture handler resolves one gesture strategy per kind, so a new
/// tool that behaves like an existing one is a single [ToolKind] entry.
enum ToolGestureKind {
  /// A freehand polyline extended point by point (pencil, eraser).
  polyline,

  /// A freehand stroke that records stylus pressure per point (brush).
  pressureStroke,

  /// A two-point shape dragged from its start (line, rectangle, circle).
  shape,

  /// A pixel-moving brush rendered once on release (smudge, blur).
  pixelBrush,

  /// A tap-to-fill with drag-to-adjust tolerance (paint bucket).
  fill,

  /// A tap that places or edits a text object.
  text,

  /// A marquee, lasso, brush or wand selection.
  selection,
}

/// Static configuration of a [ToolKind].
class _ToolConfig {
  const _ToolConfig({
    required this.icon,
    required this.gesture,
    required this.options,
    this.recordType,
  });

  final AppIcon icon;
  final ToolGestureKind gesture;
  final Set<ActionOptions> options;
  final ActionType? recordType;
}

/// A tool the user picks from the rail, the quick menu or a shortcut.
///
/// Distinct from [ActionType], which tags what a committed [UserActionDrawing]
/// is: some tools never record anything (selector) and some records come from
/// no tool (pasted images, cuts, regions).
enum ToolKind {
  pencil(
    _ToolConfig(
      icon: AppIcon.create,
      gesture: ToolGestureKind.polyline,
      recordType: ActionType.pencil,
      options: <ActionOptions>{ActionOptions.brushSize, ActionOptions.brushColor, ActionOptions.topColors},
    ),
  ),
  brush(
    _ToolConfig(
      icon: AppIcon.brush,
      gesture: ToolGestureKind.pressureStroke,
      recordType: ActionType.brush,
      options: <ActionOptions>{
        ActionOptions.brushSize,
        ActionOptions.brushStyle,
        ActionOptions.brushColor,
        ActionOptions.topColors,
      },
    ),
  ),
  smudge(
    _ToolConfig(
      icon: AppIcon.smudge,
      gesture: ToolGestureKind.pixelBrush,
      recordType: ActionType.smudge,
      options: <ActionOptions>{ActionOptions.brushSize, ActionOptions.brushIntensity},
    ),
  ),
  blurBrush(
    _ToolConfig(
      icon: AppIcon.waterDrop,
      gesture: ToolGestureKind.pixelBrush,
      recordType: ActionType.blurBrush,
      options: <ActionOptions>{ActionOptions.brushSize, ActionOptions.brushIntensity},
    ),
  ),
  line(
    _ToolConfig(
      icon: AppIcon.lineAxis,
      gesture: ToolGestureKind.shape,
      recordType: ActionType.line,
      options: <ActionOptions>{
        ActionOptions.brushColor,
        ActionOptions.brushSize,
        ActionOptions.brushStyle,
        ActionOptions.topColors,
      },
    ),
  ),
  circle(
    _ToolConfig(
      icon: AppIcon.circle,
      gesture: ToolGestureKind.shape,
      recordType: ActionType.circle,
      options: <ActionOptions>{
        ActionOptions.brushSize,
        ActionOptions.brushStyle,
        ActionOptions.brushColor,
        ActionOptions.colorFill,
        ActionOptions.topColors,
      },
    ),
  ),
  rectangle(
    _ToolConfig(
      icon: AppIcon.cropSquare,
      gesture: ToolGestureKind.shape,
      recordType: ActionType.rectangle,
      options: <ActionOptions>{
        ActionOptions.brushSize,
        ActionOptions.brushStyle,
        ActionOptions.brushColor,
        ActionOptions.colorFill,
        ActionOptions.topColors,
      },
    ),
  ),
  fill(
    _ToolConfig(
      icon: AppIcon.formatColorFill,
      gesture: ToolGestureKind.fill,
      recordType: ActionType.fill,
      options: <ActionOptions>{ActionOptions.colorFill, ActionOptions.tolerance, ActionOptions.topColors},
    ),
  ),
  eraser(
    _ToolConfig(
      icon: AppIcon.eraser,
      gesture: ToolGestureKind.polyline,
      recordType: ActionType.eraser,
      options: <ActionOptions>{ActionOptions.brushSize},
    ),
  ),
  text(
    _ToolConfig(
      icon: AppIcon.fontDownload,
      gesture: ToolGestureKind.text,
      recordType: ActionType.text,
      options: <ActionOptions>{ActionOptions.brushColor, ActionOptions.brushSize, ActionOptions.topColors},
    ),
  ),
  selector(
    _ToolConfig(
      icon: AppIcon.selector,
      gesture: ToolGestureKind.selection,
      options: <ActionOptions>{ActionOptions.selectorOptions},
    ),
  );

  const ToolKind(this._config);

  final _ToolConfig _config;

  /// The rail / quick-menu icon.
  AppIcon get icon => _config.icon;

  /// How the canvas turns this tool's pointer input into edits.
  ToolGestureKind get gesture => _config.gesture;

  /// The kind of action this tool records, or null when it records none.
  ActionType? get recordType => _config.recordType;

  /// Whether the tool exposes [option] in its tool-options panel.
  bool isSupported(ActionOptions option) => _config.options.contains(option);

  /// Whether the tool moves existing pixels (smudge, blur) rather than
  /// depositing paint.
  bool get isPixelBrush => _config.gesture == ToolGestureKind.pixelBrush;

  /// The localized rail / tooltip label.
  String label(AppLocalizations l10n) {
    return switch (this) {
      ToolKind.pencil => l10n.toolPencil,
      ToolKind.brush => l10n.toolBrush,
      ToolKind.smudge => l10n.toolSmudge,
      ToolKind.blurBrush => l10n.toolBlurBrush,
      ToolKind.line => l10n.toolLine,
      ToolKind.rectangle => l10n.toolRectangle,
      ToolKind.circle => l10n.toolCircle,
      ToolKind.fill => l10n.toolPaintBucket,
      ToolKind.eraser => l10n.toolEraser,
      ToolKind.text => l10n.toolText,
      ToolKind.selector => l10n.toolSelector,
    };
  }

  /// The brush-size range this tool accepts, matching its side-panel slider.
  ///
  /// Pixel brushes and an armed effect brush ([effectArmed]) work at much
  /// larger radii than the paint tools; the pencil starts at one pixel. An
  /// armed effect brush overrides the underlying tool's range.
  BrushSizeRange brushSizeRange({bool effectArmed = false}) {
    final bool isPencil = this == ToolKind.pencil && !effectArmed;
    return (
      min: isPencil ? AppMath.one.toDouble() : AppInteraction.minCanvasScale,
      max: effectArmed || isPixelBrush ? AppLimits.pixelBrushSizeMax.toDouble() : AppLimits.percentMax.toDouble(),
    );
  }
}

/// Inclusive brush-size bounds of a tool's size slider.
typedef BrushSizeRange = ({double min, double max});
