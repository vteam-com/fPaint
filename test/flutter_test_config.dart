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
    // Fall back to Roboto from the Flutter SDK if Inter hasn't been downloaded yet.
    await _loadFallbackRoboto();
    return;
  }

  final ByteData fontData = ByteData.view(fontFile.readAsBytesSync().buffer);
  final FontLoader loader = FontLoader(_kDefaultFontFamily)..addFont(Future<ByteData>.value(fontData));
  await loader.load();
}

/// Fallback: load Roboto from the Flutter SDK material_fonts cache.
Future<void> _loadFallbackRoboto() async {
  final String flutterRoot = _findFlutterRoot();
  final File fontFile = File('$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');

  if (!fontFile.existsSync()) {
    return;
  }

  final ByteData fontData = ByteData.view(fontFile.readAsBytesSync().buffer);
  // Load it under the Inter family name so it substitutes in tests.
  final FontLoader loader = FontLoader(_kDefaultFontFamily)..addFont(Future<ByteData>.value(fontData));
  await loader.load();
}

String _findFlutterRoot() {
  final String? envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    return envRoot;
  }

  // Resolve the `flutter` binary path through symlinks to locate the SDK root.
  final ProcessResult which = Process.runSync('which', <String>['flutter']);
  final String binPath = (which.stdout as String).trim();
  final String resolved = File(binPath).resolveSymbolicLinksSync();
  // resolved is …/flutter/bin/flutter → go up two levels.
  return File(resolved).parent.parent.path;
}
