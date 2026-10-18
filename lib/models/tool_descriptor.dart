import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/tool_kind.dart';

/// Freehand painters shown in the **Brush** section, in order. These deposit or
/// move pixels along a stroke. Smudge sits here with the other freehand brushes;
/// blur is not a gesture tool (it appears as an effect, applied to a region or
/// armed as a brush). Effects follow these in the same section.
const List<ToolKind> kBrushToolOrder = <ToolKind>[
  ToolKind.pencil,
  ToolKind.brush,
  ToolKind.smudge,
  ToolKind.eraser,
];

/// Placement / shape tools shown in the **Elements** section, in order. Unlike
/// the freehand brushes these commit a discrete shape, region, or text object
/// from a click or two-point drag rather than painting along a stroke.
const List<ToolKind> kElementToolOrder = <ToolKind>[
  ToolKind.line,
  ToolKind.rectangle,
  ToolKind.circle,
  ToolKind.fill,
  ToolKind.text,
];

/// Every gesture tool across both sections, brush painters first. Kept as the
/// union of [kBrushToolOrder] and [kElementToolOrder] so callers that reason
/// about "all gesture tools" (rail totality guards, etc.) stay correct.
const List<ToolKind> kGestureToolOrder = <ToolKind>[
  ...kBrushToolOrder,
  ...kElementToolOrder,
];

/// A single entry in the unified tool rail.
///
/// Unifies the two kinds of tools the rail presents: a gesture [tool] (Draw),
/// or a region adjustment backed by an [effect] (Adjust). Exactly one of
/// [tool] or [effect] is non-null.
class ToolDescriptor {
  /// Creates a gesture-tool entry for [tool].
  const ToolDescriptor.gesture(this.tool) : effect = null;

  /// Creates an effect entry for [effect].
  const ToolDescriptor.adjust(this.effect) : tool = null;

  /// The gesture tool for a gesture-tool entry; null for an effect.
  final ToolKind? tool;

  /// The effect for an effect entry; null for a gesture tool.
  final SelectionEffect? effect;

  /// The icon shown on the rail button.
  AppIcon get icon => effect?.icon ?? tool!.icon;

  /// The localized label / tooltip for the rail button.
  String label(AppLocalizations l10n) => effect != null ? effectLabel(l10n, effect!) : tool!.label(l10n);

  /// The bare-key shortcut that selects this tool, or null when it has none.
  ///
  /// Effects are armed from the rail only, so they never carry a key.
  String? get shortcut => effect != null ? null : toolShortcutLabel(tool!);

  @override
  bool operator ==(Object other) => other is ToolDescriptor && other.tool == tool && other.effect == effect;

  @override
  int get hashCode => Object.hash(tool, effect);
}

/// The **Brush** section: the freehand painters ([kBrushToolOrder]) followed by
/// every effect (effects arm as brushes and are painted on, so they live here).
List<ToolDescriptor> brushSectionTools() => <ToolDescriptor>[
  for (final ToolKind tool in kBrushToolOrder) ToolDescriptor.gesture(tool),
  for (final SelectionEffect effect in SelectionEffect.values) ToolDescriptor.adjust(effect),
];

/// The **Elements** section: the placement / shape tools ([kElementToolOrder]).
List<ToolDescriptor> elementSectionTools() => <ToolDescriptor>[
  for (final ToolKind tool in kElementToolOrder) ToolDescriptor.gesture(tool),
];
