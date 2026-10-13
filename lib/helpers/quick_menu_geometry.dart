import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:fpaint/constants/constants.dart';

/// Angle of the first ring slot: straight up, so the ring reads like a clock.
const double _firstSlotAngle = -math.pi / AppMath.two;

/// Distance from the centre beyond which a still-pressed pointer points at a
/// ring slot. Inside it (puck and color swatches) nothing is highlighted, so a
/// hold-and-release without moving leaves the menu open for taps.
const double quickMenuFlickRadius = AppLayout.quickMenuColorRadius + AppLayout.quickMenuSwatchSize;

/// Screen-space centre of ring slot [index] of [count] around [center],
/// running clockwise from the top.
Offset quickMenuSlotCenter({
  required Offset center,
  required int index,
  required int count,
  double radius = AppLayout.quickMenuRingRadius,
}) {
  final double angle = _firstSlotAngle + index * _slotSweep(count);
  return center + Offset(math.cos(angle), math.sin(angle)) * radius;
}

/// Screen-space centre of outer sub-ring slot [index] of [count], fanned
/// along the outer ring around inner slot [parentIndex] of [parentCount], so
/// the sub-ring opens right beside the slot that expanded it.
Offset quickMenuSubmenuSlotCenter({
  required Offset center,
  required int parentIndex,
  required int parentCount,
  required int index,
  required int count,
}) {
  const double step = AppLayout.quickMenuSubmenuSpacing / AppLayout.quickMenuOuterRingRadius;
  final double parentAngle = _firstSlotAngle + parentIndex * _slotSweep(parentCount);
  final double angle = parentAngle + (index - (count - AppMath.one) / AppMath.two) * step;
  return center + Offset(math.cos(angle), math.sin(angle)) * AppLayout.quickMenuOuterRingRadius;
}

/// The ring slot [point] points at from [center], or null while [point] is
/// still inside [quickMenuFlickRadius].
///
/// Only the direction matters past that radius, so a quick flick picks a slot
/// without the pointer having to land on its button.
int? quickMenuSlotAt({
  required Offset center,
  required Offset point,
  required int count,
}) {
  final Offset delta = point - center;
  if (count <= AppMath.zero || delta.distance < quickMenuFlickRadius) {
    return null;
  }

  final double sweep = _slotSweep(count);
  // Shift by half a sweep so each slot owns the wedge centred on it.
  final double angleFromFirst = math.atan2(delta.dy, delta.dx) - _firstSlotAngle + sweep / AppMath.two;
  final double fullTurn = math.pi * AppMath.two;
  final double normalized = (angleFromFirst % fullTurn + fullTurn) % fullTurn;
  return normalized ~/ sweep % count;
}

/// Moves [anchor] just far enough that the whole menu, including an expanded
/// sub-ring, stays inside [viewport]; a viewport too small for it centres it.
Offset clampQuickMenuAnchor(Offset anchor, Size viewport) {
  const double margin = AppLayout.quickMenuReach;
  return Offset(
    _clampAxis(anchor.dx, margin, viewport.width),
    _clampAxis(anchor.dy, margin, viewport.height),
  );
}

double _clampAxis(double value, double margin, double extent) {
  if (extent <= margin * AppMath.two) {
    return extent / AppMath.two;
  }
  return value.clamp(margin, extent - margin);
}

double _slotSweep(int count) => math.pi * AppMath.two / count;
