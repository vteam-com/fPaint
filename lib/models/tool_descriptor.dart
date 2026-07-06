import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Freehand painters shown in the **Brush** section, in order. These deposit or
/// move pixels along a stroke. Smudge sits here with the other freehand brushes;
/// blur is not a gesture tool (it appears as an effect, applied to a region or
/// armed as a brush). Effects follow these in the same section.
const List<ActionType> kBrushToolOrder = <ActionType>[
  ActionType.pencil,
  ActionType.brush,
  ActionType.smudge,
  ActionType.eraser,
];

/// Placement / shape tools shown in the **Elements** section, in order. Unlike
/// the freehand brushes these commit a discrete shape, region, or text object
/// from a click or two-point drag rather than painting along a stroke.
const List<ActionType> kElementToolOrder = <ActionType>[
  ActionType.line,
  ActionType.rectangle,
  ActionType.circle,
  ActionType.fill,
  ActionType.text,
];

/// Every gesture tool across both sections, brush painters first. Kept as the
/// union of [kBrushToolOrder] and [kElementToolOrder] so callers that reason
/// about "all gesture tools" (rail totality guards, etc.) stay correct.
const List<ActionType> kGestureToolOrder = <ActionType>[
  ...kBrushToolOrder,
  ...kElementToolOrder,
];

/// A single entry in the unified tool rail.
///
/// Unifies the two kinds of tools the rail presents: a gesture tool backed by
/// an [action] (Draw), or a region adjustment backed by an [effect] (Adjust).
/// Exactly one of [action] or [effect] is non-null.
class ToolDescriptor {
  /// Creates a gesture-tool entry for [action].
  const ToolDescriptor.gesture(this.action) : effect = null;

  /// Creates an effect entry for [effect].
  const ToolDescriptor.adjust(this.effect) : action = null;

  /// The gesture action for a gesture-tool entry; null for an effect.
  final ActionType? action;

  /// The effect for an effect entry; null for a gesture tool.
  final SelectionEffect? effect;

  /// The icon shown on the rail button.
  AppIcon get icon => effect?.icon ?? action!.icon;

  /// The localized label / tooltip for the rail button.
  String label(final AppLocalizations l10n) => effect != null ? effectLabel(l10n, effect!) : toolLabel(l10n, action!);
}

/// The **Brush** section: the freehand painters ([kBrushToolOrder]) followed by
/// every effect (effects arm as brushes and are painted on, so they live here).
List<ToolDescriptor> brushSectionTools() => <ToolDescriptor>[
  for (final ActionType action in kBrushToolOrder) ToolDescriptor.gesture(action),
  for (final SelectionEffect effect in SelectionEffect.values) ToolDescriptor.adjust(effect),
];

/// The **Elements** section: the placement / shape tools ([kElementToolOrder]).
List<ToolDescriptor> elementSectionTools() => <ToolDescriptor>[
  for (final ActionType action in kElementToolOrder) ToolDescriptor.gesture(action),
];
