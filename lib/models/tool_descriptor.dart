import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Ordered gesture tools shown in the Draw and Retouch families of the rail.
const List<ActionType> kGestureToolOrder = <ActionType>[
  ActionType.pencil,
  ActionType.brush,
  ActionType.line,
  ActionType.rectangle,
  ActionType.circle,
  ActionType.fill,
  ActionType.eraser,
  ActionType.text,
  ActionType.smudge,
  ActionType.blurBrush,
];

/// A single entry in the unified tool rail.
///
/// Unifies the two kinds of tools the rail presents: a gesture tool backed by
/// an [action] (Draw/Retouch), or a region adjustment backed by an [effect]
/// (Adjust). Exactly one of [action] or [effect] is non-null.
class ToolDescriptor {
  /// Creates a gesture-tool entry (Draw or Retouch) for [action].
  const ToolDescriptor.gesture(this.action) : effect = null;

  /// Creates a region-adjustment entry (Adjust) for [effect].
  const ToolDescriptor.adjust(this.effect) : action = null;

  /// The gesture action for a Draw/Retouch entry; null for an adjustment.
  final ActionType? action;

  /// The effect for an Adjust entry; null for a gesture tool.
  final SelectionEffect? effect;

  /// The family this tool is grouped under in the rail.
  ToolFamily get family => effect != null ? ToolFamily.adjust : familyOfAction(action!);

  /// The icon shown on the rail button.
  AppIcon get icon => effect?.icon ?? action!.icon;

  /// The localized label / tooltip for the rail button.
  String label(final AppLocalizations l10n) => effect != null ? effectLabel(l10n, effect!) : toolLabel(l10n, action!);
}

/// The full ordered tool rail: gesture tools followed by adjustments.
List<ToolDescriptor> toolRail() => <ToolDescriptor>[
  for (final ActionType action in kGestureToolOrder) ToolDescriptor.gesture(action),
  for (final SelectionEffect effect in SelectionEffect.values) ToolDescriptor.adjust(effect),
];

/// The rail entries belonging to [family], in rail order.
List<ToolDescriptor> toolsInFamily(final ToolFamily family) =>
    toolRail().where((final ToolDescriptor descriptor) => descriptor.family == family).toList();
