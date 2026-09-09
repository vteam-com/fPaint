part of 'app_provider.dart';

/// Hatch / cross-hatch settings shared by the hatch brush styles and the hatch
/// paint-bucket pattern (see `BRUSHES_AND_EFFECTS.md`, "Canvas-locked
/// patterns"). The backing field stays on [AppProvider]; this extension owns the
/// behaviour so the provider class stays within its size budget.
extension AppProviderHatch on AppProvider {
  /// The hatch line geometry (angle, spacing, thickness) used by the hatch /
  /// cross-hatch brush styles and by the hatch paint-bucket pattern. Sharing one
  /// setting keeps brushed and filled hatching aligned on the canvas.
  HatchPattern get hatchPattern => _hatchPattern;

  /// Sets the hatch geometry (clamped to the `AppHatch` bounds) and generates
  /// its tiles ahead of the next stroke. `crossed` is not part of the shared
  /// geometry — the brush style and the fill's own flag decide it — so it is
  /// normalised away here.
  set hatchPattern(HatchPattern value) {
    _hatchPattern = value.copyWith(crossed: false).clamped();
    _prewarmHatchTiles();
    repaintToolOptions();
    update();
  }

  /// The tapered-mark geometry used by the [BrushStyle.hatchMarks] style.
  HatchMarks get hatchMarks => _hatchMarks;

  /// Sets the hatch-mark geometry (clamped to the `AppHatchMarks` bounds).
  /// Marks are pure geometry, so nothing needs prewarming.
  set hatchMarks(HatchMarks value) {
    _hatchMarks = value.clamped();
    repaintToolOptions();
    update();
  }

  /// Sets whether flood fill should render as a hatch pattern (turning halftone
  /// off, the two being mutually exclusive).
  void setFillHatchEnabled(bool value) {
    fillModel.hatchEnabled = value;
    repaintToolOptions();
    update();
  }

  /// Sets whether the hatch fill pattern is cross-hatched.
  void setFillHatchCrossed(bool value) {
    fillModel.hatchCrossed = value;
    repaintToolOptions();
    update();
  }

  /// Generates the plain and crossed tiles for the current hatch geometry.
  /// Fire-and-forget into a shared singleton cache: it must not touch this
  /// provider afterwards (the future can outlive it — see the `BrushGrain`
  /// prewarm note in the constructor).
  void _prewarmHatchTiles() {
    unawaited(BrushHatch.instance.prewarm(_hatchPattern.copyWith(crossed: false)));
    unawaited(BrushHatch.instance.prewarm(_hatchPattern.copyWith(crossed: true)));
  }
}
