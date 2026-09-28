import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:fpaint/constants/constants.dart';

/// Returns the pen pressure of [event] normalized to 0..1, or null when the
/// event does not come from a pressure-sensing stylus.
///
/// Only the pen tip ([PointerDeviceKind.stylus]) counts: mice report a fixed
/// pressure, and finger pressure is unreliable across devices, so both paint at
/// the full brush size. A device that reports no pressure range (min == max)
/// is treated as pressure-less too.
double? stylusPressure(PointerEvent event) {
  if (event.kind != PointerDeviceKind.stylus) {
    return null;
  }
  final double range = event.pressureMax - event.pressureMin;
  if (range <= AppMath.zero) {
    return null;
  }
  return ((event.pressure - event.pressureMin) / range).clamp(AppMath.zero.toDouble(), AppMath.one.toDouble());
}

/// Returns the stroke width, in canvas pixels, a [brushSize] brush paints at a
/// normalized [pressure], never narrower than the
/// [AppInteraction.brushPressureMinTipWidth] hairline.
double pressureStrokeWidth(double brushSize, double pressure) {
  return max(AppInteraction.brushPressureMinTipWidth, brushSize * pressureWidthFactor(pressure));
}

/// Tapers the lift-off end of a pressure stroke: when its last sample is at
/// or below [AppInteraction.brushPressureTaperThreshold] (the press was fading
/// out), that sample drops to zero so the committed tip ends in the
/// [AppInteraction.brushPressureMinTipWidth] hairline. A firmer lift keeps its
/// blunt end. Returns whether the tip was tapered.
bool taperPressureTip(List<double> pressures) {
  if (pressures.isEmpty || pressures.last > AppInteraction.brushPressureTaperThreshold) {
    return false;
  }
  pressures[pressures.length - AppMath.one] = AppMath.zero.toDouble();
  return true;
}

/// Returns the multiple of the brush size painted at a normalized [pressure]:
/// [AppInteraction.brushPressureMinWidthFactor] at the lightest touch, rising
/// linearly to [AppInteraction.brushPressureMaxWidthFactor] at full pressure,
/// so a medium press paints at about the set brush size.
double pressureWidthFactor(double pressure) {
  const double minFactor = AppInteraction.brushPressureMinWidthFactor;
  const double maxFactor = AppInteraction.brushPressureMaxWidthFactor;
  final double clamped = pressure.clamp(AppMath.zero.toDouble(), AppMath.one.toDouble());
  return minFactor + (maxFactor - minFactor) * clamped;
}
