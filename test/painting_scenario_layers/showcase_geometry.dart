part of '../painting_scenario_test.dart';

// ---------------------------------------------------------------------------
// Scene geometry shared by the showcase layers.
//
// The showcase is an alpine lake at sunset on the default 1024 × 768 canvas.
// Every coordinate below is in CANVAS pixels; the helpers convert to screen
// positions at gesture time, so the scene is independent of zoom and panel
// layout. All "random" variation comes from fixed-seed generators so the
// painting — and therefore the regression image — is identical on every run.
// ---------------------------------------------------------------------------

/// Waterline: where the far shore meets the lake.
const double _waterlineY = 470;

/// Canvas width and height the scene is composed for (the app default).
const double _sceneWidth = 1024;
const double _sceneHeight = 768;

/// How far shapes overhang the canvas edge so no edge pixel is left unpainted.
const double _edgeBleed = 12;

/// Sun position (sits low in the notch between the two main peaks).
const Offset _sunCenter = Offset(612, 372);

/// Seeds of the deterministic generators (one per element family).
const int _starSeed = 7;
const int _pineSeed = 11;
const int _rippleSeed = 23;
const int _grassSeed = 31;
const int _glitterSeed = 41;

/// Point count used when sampling smooth waves into stroke points.
const int _waveSamples = 18;

/// A full sine period, used to shape waves.
const double _fullTurn = math.pi * AppMath.pair;

/// Samples a gentle sine wave from [from] to [to] with [amplitude] and
/// [periods] crests — the basic gesture for clouds, mist and ripples.
List<Offset> _wavePoints(
  Offset from,
  Offset to, {
  double amplitude = 0,
  double periods = 1,
  double phase = 0,
  int samples = _waveSamples,
}) {
  return <Offset>[
    for (int index = 0; index <= samples; index++)
      Offset.lerp(from, to, index / samples)! +
          Offset(0, amplitude * math.sin(phase + _fullTurn * periods * index / samples)),
  ];
}

/// Zig-zag silhouette of a pine: one continuous stroke whose swing widens from
/// the tip down to the base, the quick way painters block in conifers.
List<Offset> _pinePoints({
  required Offset base,
  required double height,
  required double width,
}) {
  final int zigs = math.max(_pineMinZigs, (height / _pineZigSpacing).round());
  final List<Offset> points = <Offset>[base + Offset(0, -height)];
  for (int zig = 1; zig <= zigs; zig++) {
    final double t = zig / zigs;
    final double halfWidth = (width / AppMath.pair) * math.pow(t, _pineFlare).toDouble();
    final double side = zig.isEven ? -1 : 1;
    points.add(base + Offset(side * halfWidth, -height + height * t));
  }
  points.add(base);
  return points;
}

/// Pine silhouette tuning.
const int _pineMinZigs = 6;
const double _pineZigSpacing = 2.2;
const double _pineFlare = 0.85;

/// A deterministic tree line along the waterline: (base, height, width) for
/// every pine, taller toward the frame edges and absent in the central gap that
/// leaves the sun's path on the water open.
List<({Offset base, double height, double width})> _pineForest() {
  final math.Random random = math.Random(_pineSeed);
  final List<({Offset base, double height, double width})> pines = <({Offset base, double height, double width})>[];
  double x = -_edgeBleed;
  while (x < _sceneWidth + _edgeBleed) {
    final bool inGap = x > _forestGapStart && x < _forestGapEnd;
    if (!inGap) {
      // 0 at the gap, 1 at the frame edges: taller trees frame the view.
      final double edgeFactor = x < _sunCenter.dx
          ? (1 - (x / _forestGapStart)).clamp(0, 1).toDouble()
          : ((x - _forestGapEnd) / (_sceneWidth - _forestGapEnd)).clamp(0, 1).toDouble();
      final double height = _pineMinHeight + _pineHeightRange * edgeFactor + random.nextDouble() * _pineHeightJitter;
      pines.add((
        base: Offset(x, _waterlineY + random.nextDouble() * _pineBaseJitter),
        height: height,
        width: height * (_pineWidthRatio + random.nextDouble() * _pineWidthJitter),
      ));
    }
    x += _pineMinGap + random.nextDouble() * _pineGapJitter;
  }
  return pines;
}

/// Forest tuning.
const double _forestGapStart = 470;
const double _forestGapEnd = 700;
const double _pineMinHeight = 22;
const double _pineHeightRange = 58;
const double _pineHeightJitter = 16;
const double _pineBaseJitter = 4;
const double _pineWidthRatio = 0.26;
const double _pineWidthJitter = 0.08;
const double _pineMinGap = 11;
const double _pineGapJitter = 13;

/// Mirrors a canvas point across the waterline (for the lake reflection).
Offset _mirrorAcrossWaterline(Offset point) => Offset(point.dx, _waterlineY * AppMath.pair - point.dy);

/// Rectangle whose vertical centre is the waterline: flipping a selection of
/// this rectangle mirrors whatever is above the waterline into the lake. It
/// stays inside the canvas so the flipped region is not cropped off-centre.
const Rect _reflectionFlipRect = Rect.fromLTRB(
  0,
  _waterlineY * AppMath.pair - _sceneHeight,
  _sceneWidth,
  _sceneHeight,
);
