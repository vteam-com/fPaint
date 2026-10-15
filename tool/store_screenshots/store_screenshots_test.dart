// Generates the App Store / Google Play screenshots.
//
// Run with `tool/store_screenshots.sh` (or
// `flutter test tool/store_screenshots/store_screenshots_test.dart`). It lives
// outside `test/` on purpose: the regular suite and its coverage gate must not
// pick it up.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/main.dart' as app;
import 'package:fpaint/panels/layers/layer_actions.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/layers_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_popup_menu.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// The showcase artwork produced by `test/painting_scenario_test.dart`.
const String _sourceArtworkPath = 'test/output/final.ora';

/// File name the artwork is opened under (it shows in the app's title bar).
const String _artworkFileName = 'Alpenglow.ora';

/// Placeholder for the store locale folder in a [_DeviceProfile.directoryTemplate].
const String _localePlaceholder = '{locale}';

/// fastlane deliver: one folder per locale; the device is inferred from the pixel size.
const String _appStoreDirectory = 'store/app_store/screenshots/$_localePlaceholder';

/// fastlane supply: phone screenshots folder.
const String _playPhoneDirectory = 'store/google_play/$_localePlaceholder/images/phoneScreenshots';

/// fastlane supply: 10-inch tablet screenshots folder.
const String _playTabletDirectory = 'store/google_play/$_localePlaceholder/images/tenInchScreenshots';

const String _iPhonePrefix = 'iphone69_';
const String _iPadPrefix = 'ipad13_';
const String _noPrefix = '';

const String _tempDirPrefix = 'fpaint_store_screenshots_';
const String _fileChannelName = 'com.vteam.fpaint/file';
const String _getPendingFileMethod = 'getPendingFile';
const String _fileUrlScheme = 'file';
const String _pathProviderChannelName = 'plugins.flutter.io/path_provider';
const String _supportDirectoryMethod = 'getApplicationSupportDirectory';
const String _pngExtension = '.png';
const String _fileNameSeparator = '_';
const String _pathSeparator = '/';
const String _indexPadding = '0';
const int _indexWidth = 2;
const int _rgbaChannels = 4;
const int _rgbChannels = 3;

const int _editorIndex = 1;
const int _artworkIndex = 2;
const int _featureIndex = 3;
const String _shotEditor = 'editor';
const String _shotArtwork = 'artwork';
const String _shotColorPicker = 'color_picker';
const String _shotLayerMenu = 'layer_menu';

const MethodChannel _fileChannel = MethodChannel(_fileChannelName);
const MethodChannel _pathProviderChannel = MethodChannel(_pathProviderChannelName);

/// Real-time slice handed to I/O and image decoding between fake-async frames.
const Duration _realAsyncStep = Duration(milliseconds: 20);

/// Fake-time frame pumped after each real-time slice.
const Duration _framePump = Duration(milliseconds: 16);

/// Upper bound on poll iterations while waiting for the app.
const int _maxPolls = 600;

/// Consecutive idle polls required before the display caches count as built.
const int _stablePollsRequired = 5;

/// Fake time that drains app timers before the test ends.
const Duration _timerDrainWait = Duration(seconds: 5);

/// Lets UI transitions (bottom sheets, panel resizes) finish.
const Duration _transitionSettle = Duration(milliseconds: 600);

/// One store device class: where its screenshots go, physical size and pixel ratio.
class _DeviceProfile {
  const _DeviceProfile({
    required this.id,
    required this.directoryTemplate,
    required this.filePrefix,
    required this.physicalWidth,
    required this.physicalHeight,
    required this.devicePixelRatio,
    required this.layersPanelHeight,
  });

  /// Identifier used in test names and by the `STORE_DEVICE` filter.
  final String id;

  /// Output folder, with [_localePlaceholder] standing for the locale folder.
  final String directoryTemplate;

  /// Prefix in front of each `NN_name.png` file name.
  final String filePrefix;

  /// Required screenshot width in physical pixels.
  final double physicalWidth;

  /// Required screenshot height in physical pixels.
  final double physicalHeight;

  /// Device pixel ratio the app is laid out with.
  final double devicePixelRatio;

  /// Height of the side panel's Layers section, in logical pixels.
  final double layersPanelHeight;

  /// Whether the device is a phone (short landscape screen).
  bool get isPhone => layersPanelHeight == _phoneLayersPanelHeight;

  /// Physical screen size.
  Size get physicalSize => Size(physicalWidth, physicalHeight);

  /// Output folder for [locale].
  String directoryFor(_StoreLocale locale) => directoryTemplate.replaceFirst(_localePlaceholder, locale.folder);
}

/// One store listing language.
class _StoreLocale {
  const _StoreLocale(this.folder, this.languageCode);

  /// Store-console locale folder name.
  final String folder;

  /// App language code stored in [AppPreferences.keyLanguageCode].
  final String languageCode;
}

const double _iPhoneWidth = 2868;
const double _iPhoneHeight = 1320;
const double _iPhoneRatio = 3;
const double _iPadWidth = 2752;
const double _iPadHeight = 2064;
const double _iPadRatio = 2;
const double _androidPhoneWidth = 1920;
const double _androidPhoneHeight = 1080;
const double _androidPhoneRatio = 2;
const double _androidTabletWidth = 2560;
const double _androidTabletHeight = 1600;
const double _androidTabletRatio = 2;

const double _phoneLayersPanelHeight = AppLayout.sidePanelTopDefault;
const double _iPadLayersPanelHeight = 560;
const double _androidTabletLayersPanelHeight = 390;

const List<_DeviceProfile> _devices = <_DeviceProfile>[
  _DeviceProfile(
    id: 'ios_iphone_69',
    directoryTemplate: _appStoreDirectory,
    filePrefix: _iPhonePrefix,
    physicalWidth: _iPhoneWidth,
    physicalHeight: _iPhoneHeight,
    devicePixelRatio: _iPhoneRatio,
    layersPanelHeight: _phoneLayersPanelHeight,
  ),
  _DeviceProfile(
    id: 'ios_ipad_13',
    directoryTemplate: _appStoreDirectory,
    filePrefix: _iPadPrefix,
    physicalWidth: _iPadWidth,
    physicalHeight: _iPadHeight,
    devicePixelRatio: _iPadRatio,
    layersPanelHeight: _iPadLayersPanelHeight,
  ),
  _DeviceProfile(
    id: 'android_phone',
    directoryTemplate: _playPhoneDirectory,
    filePrefix: _noPrefix,
    physicalWidth: _androidPhoneWidth,
    physicalHeight: _androidPhoneHeight,
    devicePixelRatio: _androidPhoneRatio,
    layersPanelHeight: _phoneLayersPanelHeight,
  ),
  _DeviceProfile(
    id: 'android_tablet_10',
    directoryTemplate: _playTabletDirectory,
    filePrefix: _noPrefix,
    physicalWidth: _androidTabletWidth,
    physicalHeight: _androidTabletHeight,
    devicePixelRatio: _androidTabletRatio,
    layersPanelHeight: _androidTabletLayersPanelHeight,
  ),
];

/// Brush color shown in the panel and the color picker: the artwork's sunset orange.
const Color _brushColor = Color(0xFFFF8A3D);

const List<_StoreLocale> _locales = <_StoreLocale>[
  _StoreLocale('en-US', 'en'),
  _StoreLocale('es-ES', 'es'),
  _StoreLocale('fr-FR', 'fr'),
];

/// Device/locale filter: `--dart-define=STORE_DEVICE=ios_ipad_13` renders one device only.
const String _deviceFilter = String.fromEnvironment('STORE_DEVICE');

/// Locale filter: `--dart-define=STORE_LOCALE=fr-FR` renders one locale only.
const String _localeFilter = String.fromEnvironment('STORE_LOCALE');

void main() {
  late Directory tempDir;
  late String artworkPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(_tempDirPrefix);
    artworkPath = '${tempDir.path}$_pathSeparator$_artworkFileName';
    File(_sourceArtworkPath).copySync(artworkPath);
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (MethodCall call) async => call.method == _supportDirectoryMethod ? tempDir.path : null,
    );
    messenger.setMockMethodCallHandler(
      _fileChannel,
      (MethodCall call) async =>
          call.method == _getPendingFileMethod ? Uri(scheme: _fileUrlScheme, path: artworkPath).toString() : null,
    );
  });

  tearDown(() {
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    messenger.setMockMethodCallHandler(_fileChannel, null);
    tempDir.deleteSync(recursive: true);
  });

  for (final _DeviceProfile device in _devices) {
    if (_deviceFilter.isNotEmpty && _deviceFilter != device.id) {
      continue;
    }
    for (final _StoreLocale locale in _locales) {
      if (_localeFilter.isNotEmpty && _localeFilter != locale.folder) {
        continue;
      }
      testWidgets('${device.id} ${locale.folder}', (WidgetTester tester) async {
        await _captureStoreScreenshots(tester, device, locale, artworkPath);
      });
    }
  }
}

/// Boots the app on [device] in [locale], opens [artworkPath] and writes the set of screenshots.
Future<void> _captureStoreScreenshots(
  WidgetTester tester,
  _DeviceProfile device,
  _StoreLocale locale,
  String artworkPath,
) async {
  // The harness is test code that lives outside test/ only to stay out of the suite.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppPreferences.keyLanguageCode: locale.languageCode,
    AppPreferences.keySidePanelDistance: device.layersPanelHeight,
    AppPreferences.keyLastBrushColor: _brushColor.toARGB32(),
  });
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.devicePixelRatio = device.devicePixelRatio;
  tester.view.physicalSize = device.physicalSize;

  await app.main();
  await _pumpUntil(tester, () => app.mainApp.shellProvider.loadedFileName == artworkPath);
  await _waitForCanvas(tester);

  final String outputDir = device.directoryFor(locale);
  // 01 — the editor: layers, brushes and the painting.
  await _save(tester, device, outputDir, _editorIndex, _shotEditor);

  // 03 — a feature close-up: the color picker on tablets, where it fits next
  // to the painting; a layer's action menu on phones, whose short landscape
  // screen would crop the picker sheet.
  if (device.isPhone) {
    await _showLayerMenu(tester, device, outputDir);
  } else {
    await _showColorPicker(tester, device, outputDir);
  }

  // 02 — full-bleed artwork: shell hidden, canvas fit to the view.
  app.mainApp.shellProvider.shellMode = ShellMode.hidden;
  await _settle(tester);
  app.mainApp.shellProvider.requestCanvasFitAndRepaint(app.mainApp.appProvider.repaintViewport);
  await _waitForCanvas(tester);
  await _save(tester, device, outputDir, _artworkIndex, _shotArtwork);

  // Let the recovery-draft debounce and other app timers run out.
  await tester.pump(AppDefaults.recoverySaveDebounce);
  await tester.pump(_timerDrainWait);
}

/// Opens the brush color picker from the panel swatch, captures it and closes it.
Future<void> _showColorPicker(WidgetTester tester, _DeviceProfile device, String outputDir) async {
  final Finder swatch = find.byKey(Keys.toolPanelBrushColor1);
  await tester.ensureVisible(swatch);
  await _settle(tester);
  await tester.tap(swatch);
  await _settle(tester);
  await _save(tester, device, outputDir, _featureIndex, _shotColorPicker);
  Navigator.of(tester.element(find.byType(ColorPickerDialog))).pop();
  await _settle(tester);
}

/// Opens the selected layer's action menu, captures it and dismisses it.
Future<void> _showLayerMenu(WidgetTester tester, _DeviceProfile device, String outputDir) async {
  // Invoked directly: on phone-sized layouts an overlay entry absorbs a
  // synthetic tap at the button's position.
  final Finder menuButton = find.descendant(
    of: find.byType(AppPopupMenuButton<LayerAction>).first,
    matching: find.byType(AppButton),
  );
  tester.widget<AppButton>(menuButton).onPressed?.call();
  await _settle(tester);
  await _save(tester, device, outputDir, _featureIndex, _shotLayerMenu);
  app.mainApp.navigatorKey.currentState!.pop();
  await _settle(tester);
}

/// Pumps frames while letting real async work progress until [condition] holds.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (int poll = 0; poll < _maxPolls && !condition(); poll++) {
    await tester.runAsync(() => Future<void>.delayed(_realAsyncStep));
    tester.binding.scheduleFrame();
    await tester.pump(_framePump);
  }
  expect(condition(), isTrue);
}

/// Pumps through a UI transition.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_transitionSettle);
  await tester.runAsync(() => Future<void>.delayed(_realAsyncStep));
  await tester.pump(_framePump);
}

/// Waits until every painted layer's display cache is built and stays put.
Future<void> _waitForCanvas(WidgetTester tester) async {
  await _settle(tester);
  final LayersProvider layers = app.mainApp.layersProvider;
  String snapshot() => layers.list.map((LayerProvider layer) => layer.displayCacheScale).join(_fileNameSeparator);
  String previous = snapshot();
  int stablePolls = 0;
  await _pumpUntil(tester, () {
    layers.repaintCanvas();
    final String current = snapshot();
    stablePolls = current == previous ? stablePolls + 1 : 0;
    previous = current;
    return stablePolls >= _stablePollsRequired;
  });
}

/// Captures the app at [device]'s physical resolution and writes an opaque PNG.
Future<void> _save(WidgetTester tester, _DeviceProfile device, String outputDir, int index, String name) async {
  await tester.pump();
  final String number = index.toString().padLeft(_indexWidth, _indexPadding);
  final String fileName = '${device.filePrefix}$number$_fileNameSeparator$name$_pngExtension';
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(Keys.appScreenshotBoundary),
    );
    final ui.Image image = await boundary.toImage(pixelRatio: device.devicePixelRatio);
    final ByteData? rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final int width = image.width;
    final int height = image.height;
    image.dispose();
    if (rgba == null) {
      throw StateError(fileName);
    }
    // Store consoles reject screenshots with an alpha channel: drop it.
    final img.Image opaque = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: _rgbaChannels,
    ).convert(numChannels: _rgbChannels);
    final File file = File('$outputDir$_pathSeparator$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(img.encodePng(opaque));
  });
}
