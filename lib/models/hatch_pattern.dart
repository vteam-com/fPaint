import 'dart:math' as math;

import 'package:fpaint/constants/constants.dart';

/// The geometry of a hatch pattern: parallel lines at [angleDegrees], every
/// [spacing] pixels, each [lineWidth] pixels thick, optionally [crossed] by a
/// second set rotated by [AppHatch.crossAngleOffsetDegrees].
///
/// Immutable value type. It is captured into each committed stroke / fill
/// (via `MyBrush.hatch` / `RegionAction.hatchPattern`) so editing the shared
/// settings later never changes what is already on the canvas.
class HatchPattern {
  const HatchPattern({
    this.angleDegrees = AppHatch.defaultAngleDegrees,
    this.spacing = AppHatch.defaultSpacing,
    this.lineWidth = AppHatch.defaultLineWidth,
    this.crossed = false,
  });

  /// Line direction in degrees; 0 is horizontal, positive turns counter-clockwise
  /// on screen. Values wrap every half turn since a line has no heading.
  final int angleDegrees;

  /// Centre-to-centre distance between neighbouring lines, in canvas pixels.
  final int spacing;

  /// Line thickness in canvas pixels.
  final int lineWidth;

  /// Whether a second, perpendicular set of lines is drawn (cross-hatch).
  final bool crossed;

  /// The line angle in radians, normalised to a half turn.
  double get angleRadians => (angleDegrees % AppHatch.maxAngleDegrees) * math.pi / AppMath.degreesPerHalfTurn;

  /// The thickness actually rendered: at least one pixel and always thinner than
  /// the spacing so a gap remains between lines.
  int get effectiveLineWidth => lineWidth.clamp(AppHatch.minLineWidth, spacing - AppMath.one);

  /// Returns a copy with the given fields replaced.
  HatchPattern copyWith({
    int? angleDegrees,
    int? spacing,
    int? lineWidth,
    bool? crossed,
  }) {
    return HatchPattern(
      angleDegrees: angleDegrees ?? this.angleDegrees,
      spacing: spacing ?? this.spacing,
      lineWidth: lineWidth ?? this.lineWidth,
      crossed: crossed ?? this.crossed,
    );
  }

  /// Returns a copy with every field clamped to the [AppHatch] bounds.
  HatchPattern clamped() {
    return HatchPattern(
      angleDegrees: angleDegrees.clamp(AppHatch.minAngleDegrees, AppHatch.maxAngleDegrees),
      spacing: spacing.clamp(AppHatch.minSpacing, AppHatch.maxSpacing),
      lineWidth: lineWidth.clamp(AppHatch.minLineWidth, AppHatch.maxLineWidth),
      crossed: crossed,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HatchPattern &&
        other.angleDegrees == angleDegrees &&
        other.spacing == spacing &&
        other.lineWidth == lineWidth &&
        other.crossed == crossed;
  }

  @override
  int get hashCode => Object.hash(angleDegrees, spacing, lineWidth, crossed);

  @override
  String toString() => 'HatchPattern(angle: $angleDegrees°, spacing: $spacing, width: $lineWidth, crossed: $crossed)';
}
