import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

// Logger name constants for each module.
const String logNameAppPreferences = 'AppPreferences';
const String logNameAppProvider = 'AppProvider';
const String logNameFileOra = 'FileOra';
const String logNameFileTiff = 'FileTiff';
const String logNameImageHelper = 'ImageHelper';
const String logNameImportFiles = 'ImportFiles';
const String logNameMyWindowManager = 'MyWindowManager';
const String logNameSave = 'Save';
const String logNameUndoProvider = 'UndoProvider';

/// Initializes the application-wide logging system.
///
/// In debug mode, all log levels are captured. In release mode,
/// only warnings and above are recorded. Records are forwarded
/// to `dart:developer` so they appear in Flutter DevTools.
void initLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((final LogRecord record) {
    developer.log(
      record.message,
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
