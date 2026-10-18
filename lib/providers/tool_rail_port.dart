import 'package:flutter/foundation.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/tool_descriptor.dart';
import 'package:fpaint/models/tool_kind.dart';

/// What the tool rail reads and changes: the one active tool or armed effect
/// brush, and that brush's size and strength.
///
/// A role interface rather than the whole app provider (Interface
/// Segregation), so the rail can be rendered against a fake.
abstract interface class ToolRailPort {
  /// Fires when the selected tool, the armed effect or its strength changes.
  Listenable get railChanges;

  /// The selected gesture tool.
  ToolKind get selectedTool;

  /// The rail entry that is active: the armed effect, else the selected tool.
  ToolDescriptor get activeTool;

  /// Activates [tool]: selects a gesture tool or arms an effect brush.
  void activateTool(ToolDescriptor tool);

  /// The effect armed as a brush, or null when none is.
  SelectionEffect? get armedEffect;

  /// Arms [effect] as the active brush.
  void armEffectBrush(SelectionEffect effect);

  /// Disarms the armed effect brush.
  void disarmEffectBrush();

  /// Strength of the armed effect brush.
  double get effectStrength;

  /// Sets the armed effect brush strength.
  void setEffectStrength(double value);

  /// The brush size the armed tool paints with.
  double get brushSize;

  /// Sets the brush size the armed tool paints with.
  set brushSize(double value);
}
