import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/smudge_helper.dart' show PixelBrushMode;

/// GPU-resident smudge/blur stroke.
///
/// The whole effect runs on the GPU via a fragment shader: each dab records a
/// picture that redraws the working image through the shader and resolves it
/// with `Picture.toImageSync()`. The result stays a GPU texture — there is
/// never a `toByteData()` readback, which is what previously stalled the live
/// preview for seconds while dragging.
///
/// Dabs are synchronous and cheap, so the gesture handler can apply one per
/// pointer-move and repaint immediately.
class GpuPixelBrushStroke {
  GpuPixelBrushStroke._(this._program, this._working);

  final ui.FragmentProgram _program;

  /// Current accumulated image (layer + effect so far). Displayed each frame.
  ui.Image _working;

  /// Set once the final image has been handed to the commit path; a late
  /// in-flight dab must then discard its result instead of touching [_working].
  bool _detached = false;

  static ui.FragmentProgram? _cachedProgram;

  ui.Image get image => _working;
  int get width => _working.width;
  int get height => _working.height;

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
  /// [baseline] transfers to the stroke.
  static GpuPixelBrushStroke create({
    required final ui.FragmentProgram program,
    required final ui.Image baseline,
  }) => GpuPixelBrushStroke._(program, baseline);

  /// Applies one dab dragging from [from] to [to], synchronously.
  ///
  /// Uses `toImageSync`: it returns immediately and the GPU rasterizes lazily on
  /// the raster thread at frame rate, so the live preview updates every frame
  /// without any starvable async completion. The Flutter engine ref-counts the
  /// underlying texture, so disposing the previous image here is safe even while
  /// a pending raster still samples it.
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

    // Brush bounding rect: only this region changes, so the rest of the canvas
    // is a cheap blit of the previous image.
    final double pad = radius + 2.0;
    final double left = math.max(0, math.min(from.dx, to.dx) - pad);
    final double top = math.max(0, math.min(from.dy, to.dy) - pad);
    final double right = math.min(width.toDouble(), math.max(from.dx, to.dx) + pad);
    final double bottom = math.min(height.toDouble(), math.max(from.dy, to.dy) + pad);
    final ui.Rect dabRect = ui.Rect.fromLTRB(left, top, right, bottom);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawImage(_working, ui.Offset.zero, ui.Paint());

    ui.FragmentShader? shader;
    if (dabRect.width > 0 && dabRect.height > 0) {
      if (mode == PixelBrushMode.smudge) {
        final double strength = AppInteraction.smudgeBlendStrength * appliedIntensity;
        shader = _program.fragmentShader();
        shader.setFloat(0, width.toDouble());
        shader.setFloat(1, height.toDouble());
        shader.setFloat(2, from.dx);
        shader.setFloat(3, from.dy);
        shader.setFloat(4, to.dx);
        shader.setFloat(5, to.dy);
        shader.setFloat(6, radius);
        shader.setFloat(7, strength);
        shader.setFloat(8, 0.0);
        shader.setFloat(9, 1.0);
        shader.setImageSampler(0, _working);
        canvas.drawRect(
          dabRect,
          ui.Paint()
            ..shader = shader
            ..blendMode = ui.BlendMode.src,
        );
      } else {
        // Blur: composite an engine Gaussian-blurred copy of the working image,
        // masked to a radially-feathered disc. Using ui.ImageFilter.blur handles
        // premultiplied alpha correctly (a hand-rolled average garbles colour at
        // the layer's transparent edges) and gives a smooth, real blur.
        final double sigma = math.max(1.0, radius * (0.12 + 0.4 * clampedIntensity));
        final double centerAlpha = (AppInteraction.blurBrushStrength * appliedIntensity).clamp(0.0, 1.0);
        canvas
          ..saveLayer(dabRect, ui.Paint())
          ..clipRect(dabRect)
          ..drawImage(
            _working,
            ui.Offset.zero,
            ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          )
          ..drawRect(
            dabRect,
            ui.Paint()
              ..blendMode = ui.BlendMode.dstIn
              ..shader = ui.Gradient.radial(
                to,
                radius,
                <ui.Color>[
                  ui.Color.fromARGB((centerAlpha * 255).round(), 255, 255, 255),
                  const ui.Color(0x00FFFFFF),
                ],
              ),
          )
          ..restore();
      }
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image next = picture.toImageSync(width, height);
    picture.dispose();
    shader?.dispose();

    final ui.Image previous = _working;
    _working = next;
    previous.dispose();
  }

  /// Returns the final image and relinquishes ownership (the caller must dispose
  /// it once committed). Any in-flight dab will discard its result.
  ui.Image detachImage() {
    _detached = true;
    return _working;
  }

  /// Disposes all images held by the stroke. Use when abandoning without commit.
  void dispose() {
    _detached = true;
    _working.dispose();
  }
}
