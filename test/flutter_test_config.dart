import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Font family name used by the app.
const String _kDefaultFontFamily = 'packages/fpaint_assets/Inter';

/// The Inter faces bundled with the app, keyed by the weight they supply.
///
/// All four are registered, not just Regular: a [FontLoader] family only
/// resolves the weights it was given, so a bold text object measured against a
/// Regular-only family silently falls back to the harness's block font.
const Map<int, String> _kInterFontFilenames = <int, String>{
  400: 'Inter-Regular.otf',
  500: 'Inter-Medium.otf',
  600: 'Inter-SemiBold.otf',
  700: 'Inter-Bold.otf',
};

/// Path within the workspace to the bundled font assets.
const String _kAppFontsRelativePath = 'packages/fpaint_assets/assets/fonts';

/// Loads the Inter font so text renders legibly in
/// golden-file screenshots and widget tests instead of showing as white boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadInterFont();
  await testMain();
}

Future<void> _loadInterFont() async {
  final FontLoader loader = FontLoader(_kDefaultFontFamily);
  bool loadedAny = false;

  for (final String filename in _kInterFontFilenames.values) {
    final File fontFile = File('$_kAppFontsRelativePath/$filename');
    if (!fontFile.existsSync()) {
      continue;
    }
    final ByteData fontData = ByteData.view(fontFile.readAsBytesSync().buffer);
    loader.addFont(Future<ByteData>.value(fontData));
    loadedAny = true;
  }

  if (!loadedAny) {
    // Inter fonts not found — tests will use the default Flutter test font.
    return;
  }

  await loader.load();
}
