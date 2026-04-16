import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Font family name used by Material widgets by default.
const String _kDefaultFontFamily = 'Roboto';

/// Filename of the regular-weight Roboto font bundled with the Flutter SDK.
const String _kRobotoFontFilename = 'Roboto-Regular.ttf';

/// Relative path from the Flutter SDK root to the material fonts directory.
const String _kMaterialFontsRelativePath = 'bin/cache/artifacts/material_fonts';

/// Loads the Roboto font from the Flutter SDK so text renders legibly in
/// golden-file screenshots and widget tests instead of showing as white boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRobotoFont();
  await testMain();
}

Future<void> _loadRobotoFont() async {
  final String flutterRoot = _findFlutterRoot();
  final File fontFile = File(
    '$flutterRoot/$_kMaterialFontsRelativePath/$_kRobotoFontFilename',
  );

  if (!fontFile.existsSync()) {
    return;
  }

  final ByteData fontData = ByteData.view(
    fontFile.readAsBytesSync().buffer,
  );
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
