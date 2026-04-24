import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Font family name used by the app.
const String _kDefaultFontFamily = 'Inter';

/// Regular-weight Inter font bundled with the app.
const String _kInterFontFilename = 'Inter-Regular.otf';

/// Path within the workspace to the bundled font assets.
const String _kAppFontsRelativePath = 'assets/fonts';

/// Loads the Inter font so text renders legibly in
/// golden-file screenshots and widget tests instead of showing as white boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadInterFont();
  await testMain();
}

Future<void> _loadInterFont() async {
  final File fontFile = File('$_kAppFontsRelativePath/$_kInterFontFilename');

  if (!fontFile.existsSync()) {
    // Inter font not found — tests will use the default Flutter test font.
    return;
  }

  final ByteData fontData = ByteData.view(fontFile.readAsBytesSync().buffer);
  final FontLoader loader = FontLoader(_kDefaultFontFamily)..addFont(Future<ByteData>.value(fontData));
  await loader.load();
}
