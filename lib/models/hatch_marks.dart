import 'dart:math' as math;

import 'package:fpaint/constants/constants.dart';

/// The geometry of **hatch marks**: tapered strokes emitted every [spacing]
/// pixels along the brush path, each [length] pixels long, heading
/// [angleDegrees] from the stroke direction, thinning/fading by [taperPercent]
/// toward the tip and bending by [curvePercent].
///
/// Immutable value type, captured into each committed stroke via
/// `MyBrush.marks` so editing the shared settings later never changes what is
/// already on the canvas. The mark's thickness at its base is the brush size.
class HatchMarks {
  const HatchMarks({
    this.angleDegrees = AppHatchMarks.defaultAngleDegrees,
    this.spacing = AppHatchMarks.defaultSpacing,
    this.length = AppHatchMarks.defaultLength,
    this.taperPercent = AppHatchMarks.defaultTaperPercent,
    this.curvePercent = AppHatchMarks.defaultCurvePercent,
  });

  /// Mark direction relative to the stroke heading, in degrees; 90 is
  /// perpendicular. Direction matters because the mark tapers toward its tip.
  final int angleDegrees;

  /// Distance between consecutive marks along the stroke, in canvas pixels.
  final int spacing;

  /// Mark length in canvas pixels.
  final int length;

  /// How much the mark thins and fades toward its tip: 0 keeps the brush width
  /// and full opacity end to end, 100 thins to a point and fades to nothing.
  final int taperPercent;

  /// How much the mark bends: 0 is straight, positive bends left of the mark
  /// direction, negative right.
  final int curvePercent;

  /// The relative angle in radians, normalised to a full turn.
  double get angleRadians => (angleDegrees % AppHatchMarks.maxAngleDegrees) * math.pi / AppMath.degreesPerHalfTurn;

  /// The taper as a `0..1` fraction.
  double get taper => taperPercent / AppMath.percentScale;

  /// The curve as a `-1..1` fraction.
  double get curve => curvePercent / AppMath.percentScale;

  /// Returns a copy with the given fields replaced.
  HatchMarks copyWith({
    int? angleDegrees,
    int? spacing,
    int? length,
    int? taperPercent,
    int? curvePercent,
  }) {
    return HatchMarks(
      angleDegrees: angleDegrees ?? this.angleDegrees,
      spacing: spacing ?? this.spacing,
      length: length ?? this.length,
      taperPercent: taperPercent ?? this.taperPercent,
      curvePercent: curvePercent ?? this.curvePercent,
    );
  }

  /// Returns a copy with every field clamped to the [AppHatchMarks] bounds.
  HatchMarks clamped() {
    return HatchMarks(
      angleDegrees: angleDegrees.clamp(AppHatchMarks.minAngleDegrees, AppHatchMarks.maxAngleDegrees),
      spacing: spacing.clamp(AppHatchMarks.minSpacing, AppHatchMarks.maxSpacing),
      length: length.clamp(AppHatchMarks.minLength, AppHatchMarks.maxLength),
      taperPercent: taperPercent.clamp(AppMath.zero, AppLimits.percentMax),
      curvePercent: curvePercent.clamp(AppHatchMarks.minCurvePercent, AppHatchMarks.maxCurvePercent),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HatchMarks &&
        other.angleDegrees == angleDegrees &&
        other.spacing == spacing &&
        other.length == length &&
        other.taperPercent == taperPercent &&
        other.curvePercent == curvePercent;
  }

  @override
  int get hashCode => Object.hash(angleDegrees, spacing, length, taperPercent, curvePercent);

  @override
  String toString() =>
      'HatchMarks(angle: $angleDegrees°, spacing: $spacing, length: $length, taper: $taperPercent%, curve: $curvePercent%)';
}
