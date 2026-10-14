library;

// ignore_for_file: use_build_context_synchronously

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/main.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/models/hatch_marks.dart';
import 'package:fpaint/models/hatch_pattern.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/models/selector_model.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/panels/layers/layer_thumbnail.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/main_view.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/tolerance_picker.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/painting_test_helpers.dart';
import 'helpers/showcase_painting_helpers.dart';

part 'painting_scenario_layers/scenario_coverage_exercises.dart';
part 'painting_scenario_layers/scenario_crop_canvas.dart';
part 'painting_scenario_layers/scenario_export_outputs.dart';
part 'painting_scenario_layers/scenario_validate_scene.dart';
part 'painting_scenario_layers/showcase_birds.dart';
part 'painting_scenario_layers/showcase_cabin.dart';
part 'painting_scenario_layers/showcase_clouds.dart';
part 'painting_scenario_layers/showcase_geometry.dart';
part 'painting_scenario_layers/showcase_lake.dart';
part 'painting_scenario_layers/showcase_mist.dart';
part 'painting_scenario_layers/showcase_mountains.dart';
part 'painting_scenario_layers/showcase_shore.dart';
part 'painting_scenario_layers/showcase_shoreline.dart';
part 'painting_scenario_layers/showcase_signature.dart';
part 'painting_scenario_layers/showcase_sky.dart';
part 'painting_scenario_layers/showcase_vignette.dart';

// ---------------------------------------------------------------------------
// Showcase scenario: "Alpenglow" — an alpine lake at sunset, painted end to
// end through the real UI. It doubles as the visual regression check (a human
// reviews test/output/final.*) and the product demo (test/output/
// unit_test_video.mp4 replays every interaction at high speed).
// ---------------------------------------------------------------------------

const String _testLanguageCode = 'en';
const double _testSidePanelSplitHeight = 400.0;
const Map<String, Object> _testPreferences = <String, Object>{
  AppPreferences.keyLanguageCode: _testLanguageCode,
  AppPreferences.keySidePanelDistance: _testSidePanelSplitHeight,
};

const double _scenarioViewportHeightScale = 1.5;
const int _coverageDialogTransitionMs = 300;
const Duration _paintingScenarioTestTimeout = Duration(minutes: 20);
const int _scenarioTimingSecondsPerMinute = 60;
const int _scenarioTimingMillisecondsPerSecond = 1000;

/// Paints only the scene (skipping the coverage exercises) when run with
/// `--dart-define=FPAINT_SHOWCASE_ONLY=true` — handy while iterating on the art.
const bool _showcaseOnly = bool.fromEnvironment('FPAINT_SHOWCASE_ONLY');

const String _backgroundLayerName = 'Background';

/// Expected stack, top to bottom, once the scene is finished.
const List<String> _expectedSceneLayerNames = <String>[
  _signatureLayerName,
  _birdsLayerName,
  _vignetteLayerName,
  _cabinLayerName,
  _shoreLayerName,
  _shorelineLayerName,
  _reflectionLayerName,
  _lakeLayerName,
  _mistLayerName,
  _mountainsLayerName,
  _cloudsLayerName,
  _sunLayerName,
  _skyLayerName,
  _backgroundLayerName,
];
final int _expectedLayerCountAfterScene = _expectedSceneLayerNames.length;

// Screenshot filenames
const String _finalOraFilename = 'final.ora';
const String _finalPngFilename = 'final.png';
const String _finalJpegFilename = 'final.jpg';
const String _finalTiffFilename = 'final.tif';
const String _finalWebpFilename = 'final.webp';

class PaintingScenarioSession {
  const PaintingScenarioSession({
    required this.tester,
    required this.canvasCenter,
    required this.videoRecorder,
  });

  final WidgetTester tester;
  final Offset canvasCenter;
  final UnitTestVideoRecorder videoRecorder;
}

class _ScenarioPhaseTiming {
  const _ScenarioPhaseTiming({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration duration;
}

String _formatScenarioDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(_scenarioTimingSecondsPerMinute);
  final int milliseconds = duration.inMilliseconds.remainder(_scenarioTimingMillisecondsPerSecond);
  return '${minutes}m ${seconds}s ${milliseconds}ms';
}

Future<void> _runTimedScenarioPhase(
  List<_ScenarioPhaseTiming> phaseTimings, {
  required String label,
  required Future<void> Function() phase,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  await phase();
  stopwatch.stop();
  phaseTimings.add(
    _ScenarioPhaseTiming(
      label: label,
      duration: stopwatch.elapsed,
    ),
  );
  debugPrint(
    '⏱️ Scenario phase complete: $label (${_formatScenarioDuration(stopwatch.elapsed)})',
  );
}

Future<T> _runTimedScenarioPhaseWithValue<T>(
  List<_ScenarioPhaseTiming> phaseTimings, {
  required String label,
  required Future<T> Function() phase,
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  final T value = await phase();
  stopwatch.stop();
  phaseTimings.add(
    _ScenarioPhaseTiming(
      label: label,
      duration: stopwatch.elapsed,
    ),
  );
  debugPrint(
    '⏱️ Scenario phase complete: $label (${_formatScenarioDuration(stopwatch.elapsed)})',
  );
  return value;
}

void _printScenarioTimingSummary(
  List<_ScenarioPhaseTiming> phaseTimings, {
  required Duration totalDuration,
}) {
  final List<_ScenarioPhaseTiming> sortedTimings = List<_ScenarioPhaseTiming>.from(phaseTimings)
    ..sort(
      (_ScenarioPhaseTiming left, _ScenarioPhaseTiming right) => right.duration.compareTo(left.duration),
    );

  debugPrint(
    '⏱️ Scenario timing summary (total ${_formatScenarioDuration(totalDuration)}):',
  );
  for (int index = 0; index < sortedTimings.length; index++) {
    final _ScenarioPhaseTiming timing = sortedTimings[index];
    debugPrint(
      '   ${index + 1}. ${timing.label}: ${_formatScenarioDuration(timing.duration)}',
    );
  }
}

void main() {
  SharedPreferences.setMockInitialValues(_testPreferences);

  group('Painting Scenario (Unit Test)', () {
    /// Painting scenario runs entirely in unit tests without a simulator
    testWidgets('Paint alpine lake showcase', (WidgetTester tester) async {
      // ---------------------------------------------------------------
      // Boot the full app — no simulator, no emulator, just widget test
      // ---------------------------------------------------------------
      configureTestViewport(tester);

      // Use a taller viewport for this scenario so more of the app UI is visible.
      tester.view.physicalSize = Size(
        tester.view.physicalSize.width,
        tester.view.physicalSize.height * _scenarioViewportHeightScale,
      );
      await tester.pump();

      await tester.pumpWidget(MyApp());
      await pumpForUnitTestUiSettle(tester);
      await prepareCanvasViewport(tester);
      await showActualSizeCentered(tester);

      final UnitTestVideoRecorder videoRecorder = UnitTestVideoRecorder(tester);
      await videoRecorder.start();

      final Offset canvasCenter = tester.getCenter(find.byType(MainView));
      final PaintingScenarioSession session = PaintingScenarioSession(
        tester: tester,
        canvasCenter: canvasCenter,
        videoRecorder: videoRecorder,
      );

      final Stopwatch scenarioStopwatch = Stopwatch()..start();
      final List<_ScenarioPhaseTiming> phaseTimings = <_ScenarioPhaseTiming>[];

      final List<(String, Future<void> Function(PaintingScenarioSession))> scenePhases =
          <(String, Future<void> Function(PaintingScenarioSession))>[
            ('sky', paintShowcaseSky),
            ('sun', paintShowcaseSun),
            ('clouds', paintShowcaseClouds),
            ('mountains', paintShowcaseMountains),
            ('mist', paintShowcaseMist),
            ('lake', paintShowcaseLake),
            ('reflection', paintShowcaseReflection),
            ('shoreline', paintShowcaseShoreline),
            ('shore', paintShowcaseShore),
            ('cabin', paintShowcaseCabin),
            ('vignette', paintShowcaseVignette),
            ('birds', paintShowcaseBirds),
          ];
      for (final (String label, Future<void> Function(PaintingScenarioSession) paint) in scenePhases) {
        await _runTimedScenarioPhase(
          phaseTimings,
          label: label,
          phase: () async {
            await paint(session);
            await session.videoRecorder.captureFrame();
          },
        );
      }

      final LayersProvider layersProvider = await _runTimedScenarioPhaseWithValue<LayersProvider>(
        phaseTimings,
        label: 'crop',
        phase: () => cropScenarioCanvas(session),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'signature',
        phase: () => paintShowcaseSignature(session, layersProvider: layersProvider),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'validate',
        phase: () => validateScenarioScene(session, layersProvider: layersProvider),
      );
      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'export',
        phase: () => exportScenarioOutputs(session),
      );

      if (!_showcaseOnly) {
        // Capture the scene state before coverage exercises.
        final int layerCountBefore = layersProvider.length;
        final double canvasWidthBefore = layersProvider.width;
        final double canvasHeightBefore = layersProvider.height;
        final List<String> layerNamesBefore = <String>[
          for (int i = 0; i < layersProvider.length; i++) layersProvider.get(i).name,
        ];
        final List<int> actionCountsBefore = <int>[
          for (int i = 0; i < layersProvider.length; i++) layersProvider.get(i).actionStack.length,
        ];

        videoRecorder.pauseAutoCapture();
        await _runTimedScenarioPhase(
          phaseTimings,
          label: 'coverage exercises',
          phase: () => exerciseCoverageScenarios(session),
        );
        videoRecorder.resumeAutoCapture();

        // Each exercise cleans up after itself. Verify the scene is unchanged.
        expect(layersProvider.length, layerCountBefore);
        expect(layersProvider.width, canvasWidthBefore);
        expect(layersProvider.height, canvasHeightBefore);
        for (int i = 0; i < layerCountBefore; i++) {
          expect(layersProvider.get(i).name, layerNamesBefore[i]);
          expect(
            layersProvider.get(i).isVisible,
            isTrue,
            reason: 'Layer "${layersProvider.get(i).name}" at index $i should be visible',
          );
          expect(
            layersProvider.get(i).actionStack.length,
            actionCountsBefore[i],
            reason:
                'Layer "${layersProvider.get(i).name}" actionStack changed from ${actionCountsBefore[i]} to ${layersProvider.get(i).actionStack.length}',
          );
        }
      }

      // End the video on the finished painting, pixel for pixel.
      await showActualSizeCentered(tester);

      await _runTimedScenarioPhase(
        phaseTimings,
        label: 'video assembly',
        phase: () => videoRecorder.stop(),
      );

      // Drain any pending debounce timers to avoid a "Pending timers" warning.
      await tester.pump(AppDefaults.thumbnailDebounceDuration);

      scenarioStopwatch.stop();
      _printScenarioTimingSummary(
        phaseTimings,
        totalDuration: scenarioStopwatch.elapsed,
      );

      debugPrint(
        '✅ Full painting scenario completed',
      );
    }, timeout: const Timeout(_paintingScenarioTestTimeout));
  });
}
