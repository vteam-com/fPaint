import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/effect_labels.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_family.dart';
import 'package:fpaint/models/user_action_drawing.dart';

/// Ordered gesture tools shown first in the Brush section of the rail. Smudge
/// sits with the freehand brushes; blur is not a gesture tool (it appears as an
/// effect, applied to a region or armed as a brush).
const List<ActionType> kGestureToolOrder = <ActionType>[
  ActionType.pencil,
  ActionType.brush,
  ActionType.smudge,
  ActionType.line,
  ActionType.rectangle,
  ActionType.circle,
  ActionType.fill,
  ActionType.eraser,
  ActionType.text,
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

/// The full ordered tool rail: gesture tools followed by effects.
List<ToolDescriptor> toolRail() => <ToolDescriptor>[
  for (final ActionType action in kGestureToolOrder) ToolDescriptor.gesture(action),
  for (final SelectionEffect effect in SelectionEffect.values) ToolDescriptor.adjust(effect),
];
