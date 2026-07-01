import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/smudge_helper.dart' show PixelBrushMode;

/// GPU-resident smudge/blur stroke, bounded to the stroke's dirty region.
///
/// This mirrors how professional brush engines stay real-time: the layer's
/// full-canvas [_baseline] is a single immutable texture that never changes
/// during the stroke, and each dab rasterizes only a small **patch** covering
/// the stroke's dirty rect so far — never the whole canvas. Cost per dab scales
/// with the brush/stroke footprint, not the canvas size, so a 5000×9000 canvas
/// costs the same per dab as a tiny one. There is never a `toByteData()`
/// readback.
///
/// Display composites [_baseline] + [_patch] (via the layer's
/// `setLivePixelBrushPatch`); commit flattens them once into a full-canvas image.
class GpuPixelBrushStroke {
  GpuPixelBrushStroke._(this._program, this._baseline);

  final ui.FragmentProgram _program;

  /// Immutable full-canvas image captured at stroke start. Never mutated; used
  /// read-only to seed newly-touched patch regions and to composite at commit.
  final ui.Image _baseline;

  /// Accumulated effect within [_patchBounds]; null until the first dab. Sized to
  /// the dirty rect, not the canvas. Owned by this stroke.
  ui.Image? _patch;
  ui.Rect _patchBounds = ui.Rect.zero;

  /// Set once the final image has been handed to the commit path; a late
  /// in-flight dab must then discard its result instead of touching state.
  bool _detached = false;

  static ui.FragmentProgram? _cachedProgram;

  /// Width in pixels of the canvas (baseline) this stroke targets.
  int get width => _baseline.width;

  /// Height in pixels of the canvas (baseline) this stroke targets.
  int get height => _baseline.height;

  /// The current dirty-rect patch (effect so far), or null before the first dab.
  /// The stroke retains ownership; the display references it read-only.
  ui.Image? get patch => _patch;

  /// Canvas-space bounds of [patch].
  ui.Rect get patchBounds => _patchBounds;

  /// Loads and caches the pixel-brush shader. Returns null if it cannot be
  /// loaded, so callers fall back to the CPU path.
  static Future<ui.FragmentProgram?> loadProgram() async {
    if (_cachedProgram != null) {
      return _cachedProgram;
    }
    try {
      _cachedProgram = await ui.FragmentProgram.fromAsset('shaders/pixel_brush.frag');
    } on Object {
      _cachedProgram = null;
    }
    return _cachedProgram;
  }

  /// Returns the cached program if it has already been loaded.
  static ui.FragmentProgram? get loadedProgram => _cachedProgram;

  /// Seeds a stroke with [baseline] (a GPU-resident image). Ownership of
  /// [baseline] transfers to the stroke (freed at [compositeAndDetach]/[dispose]).
  static GpuPixelBrushStroke create({
    required final ui.FragmentProgram program,
    required final ui.Image baseline,
  }) => GpuPixelBrushStroke._(program, baseline);

  /// Applies one dab dragging from [from] to [to], synchronously.
  ///
  /// Rasterizes only the dab's footprint (unioned into the running patch), so the
  /// cost is O(dirty region), never O(canvas). Uses `toImageSync`; the engine
  /// ref-counts textures, so disposing the prior patch here is safe even while a
  /// pending raster still samples it.
  void dab({
    required final ui.Offset from,
    required final ui.Offset to,
    required final double brushSize,
    required final double intensity,
    required final PixelBrushMode mode,
  }) {
    if (_detached) {
      return;
    }
    final double radius = math.max(
      AppInteraction.smudgeMinimumRadius,
      brushSize * AppInteraction.smudgeBrushRadiusFactor,
    );
    final double clampedIntensity = intensity.clamp(AppEffects.minIntensity, AppEffects.maxIntensity);
    final double appliedIntensity = clampedIntensity * AppInteraction.pixelBrushIntensityAppliedScale;

    // Footprint of this dab in canvas coords (covers both from and to, plus the
    // feathered brush edge). Only this region — unioned into the patch — is
    // rasterized.
    final double pad = radius + AppInteraction.smudgeGpuDabPadding;
    final double dl = math.max(0, math.min(from.dx, to.dx) - pad);
    final double dt = math.max(0, math.min(from.dy, to.dy) - pad);
    final double dr = math.min(width.toDouble(), math.max(from.dx, to.dx) + pad);
    final double db = math.min(height.toDouble(), math.max(from.dy, to.dy) + pad);
    if (dr <= dl || db <= dt) {
      return;
    }
    final ui.Rect dabRect = ui.Rect.fromLTRB(dl, dt, dr, db);

    // Grow the patch to include this dab, integer-aligned and clamped to canvas.
    final ui.Rect union = _patch == null ? dabRect : _patchBounds.expandToInclude(dabRect);
    final ui.Rect nb = ui.Rect.fromLTRB(
      union.left.floorToDouble(),
      union.top.floorToDouble(),
      math.min(width.toDouble(), union.right.ceilToDouble()),
      math.min(height.toDouble(), union.bottom.ceilToDouble()),
    );
    final int pw = nb.width.toInt();
    final int ph = nb.height.toInt();
    if (pw <= 0 || ph <= 0) {
      return;
    }

    // Build the current working state within the new patch bounds: the baseline
    // sub-region, with the prior patch overlaid where it existed.
    final ui.Image input = _renderInput(nb, pw, ph);

    // Apply the effect over the input, in patch-local coordinates.
    final ui.Rect localDab = dabRect.shift(-nb.topLeft);
    final ui.Offset localFrom = from - nb.topLeft;
    final ui.Offset localTo = to - nb.topLeft;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImage(input, ui.Offset.zero, ui.Paint());

    ui.FragmentShader? shader;
    if (mode == PixelBrushMode.smudge) {
      final double strength = AppInteraction.smudgeBlendStrength * appliedIntensity;
      shader = _program.fragmentShader();
      shader.setFloat(AppInteraction.pixelBrushShaderSlotWidth, pw.toDouble());
      shader.setFloat(AppInteraction.pixelBrushShaderSlotHeight, ph.toDouble());
      shader.setFloat(AppInteraction.pixelBrushShaderSlotFromX, localFrom.dx);
      shader.setFloat(AppInteraction.pixelBrushShaderSlotFromY, localFrom.dy);
      shader.setFloat(AppInteraction.pixelBrushShaderSlotToX, localTo.dx);
      shader.setFloat(AppInteraction.pixelBrushShaderSlotToY, localTo.dy);
      shader.setFloat(AppInteraction.pixelBrushShaderSlotRadius, radius);
      shader.setFloat(AppInteraction.pixelBrushShaderSlotStrength, strength);
      shader.setImageSampler(AppInteraction.pixelBrushShaderSamplerTexture, input);
      canvas.drawRect(
        localDab,
        ui.Paint()
          ..shader = shader
          ..blendMode = ui.BlendMode.src,
      );
    } else {
      // Blur: engine Gaussian blur of the input, masked to a radially-feathered
      // disc. ui.ImageFilter.blur handles premultiplied alpha correctly.
      final double sigma = math.max(1.0, radius * (0.12 + 0.4 * clampedIntensity));
      final double centerAlpha = (AppInteraction.blurBrushStrength * appliedIntensity).clamp(0.0, 1.0);
      canvas
        ..saveLayer(localDab, ui.Paint())
        ..clipRect(localDab)
        ..drawImage(
          input,
          ui.Offset.zero,
          ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        )
        ..drawRect(
          localDab,
          ui.Paint()
            ..blendMode = ui.BlendMode.dstIn
            ..shader = ui.Gradient.radial(
              localTo,
              radius,
              <ui.Color>[
                ui.Color.fromARGB(
                  (centerAlpha * AppLimits.rgbChannelMax).round(),
                  AppLimits.rgbChannelMax,
                  AppLimits.rgbChannelMax,
                  AppLimits.rgbChannelMax,
                ),
                AppColors.transparentWhite,
              ],
            ),
        )
        ..restore();
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image next = picture.toImageSync(pw, ph);
    picture.dispose();
    shader?.dispose();
    input.dispose();

    final ui.Image? previousPatch = _patch;
    _patch = next;
    _patchBounds = nb;
    previousPatch?.dispose();
  }

  /// Rasterizes the working state within [bounds] (baseline sub-region plus the
  /// prior patch overlaid) into a [pw]×[ph] texture for the shader to sample.
  ui.Image _renderInput(final ui.Rect bounds, final int pw, final int ph) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      _baseline,
      bounds,
      ui.Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()),
      ui.Paint(),
    );
    final ui.Image? patch = _patch;
    if (patch != null) {
      canvas.drawImageRect(
        patch,
        ui.Rect.fromLTWH(0, 0, _patchBounds.width, _patchBounds.height),
        ui.Rect.fromLTWH(
          _patchBounds.left - bounds.left,
          _patchBounds.top - bounds.top,
          _patchBounds.width,
          _patchBounds.height,
        ),
        ui.Paint(),
      );
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image input = picture.toImageSync(pw, ph);
    picture.dispose();
    return input;
  }

  /// Flattens baseline + patch into a concrete full-canvas image for commit, then
  /// releases the stroke's textures. Concrete (async `toImage`) so the committed
  /// image does not retain the baseline/patch as a lazy dependency chain.
  Future<ui.Image> compositeAndDetach() async {
    _detached = true;
    final ui.Image committed = await renderCanvasImage(
      width: width,
      height: height,
      draw: (final ui.Canvas canvas) {
        canvas.drawImage(_baseline, ui.Offset.zero, ui.Paint());
        final ui.Image? patch = _patch;
        if (patch != null) {
          canvas.drawImage(patch, _patchBounds.topLeft, ui.Paint());
        }
      },
    );
    _baseline.dispose();
    _patch?.dispose();
    _patch = null;
    return committed;
  }

  /// Disposes all images held by the stroke. Use when abandoning without commit.
  void dispose() {
    _detached = true;
    _baseline.dispose();
    _patch?.dispose();
    _patch = null;
  }
}
