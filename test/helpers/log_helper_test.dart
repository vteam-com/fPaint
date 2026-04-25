import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:logging/logging.dart';

void main() {
  group('initLogging', () {
    test('configures root logger level and listener', () {
      initLogging();

      // Root logger should accept all levels in debug mode
      expect(Logger.root.level, Level.ALL);

      // Verify logging works by emitting a test record
      final Logger testLogger = Logger('TestLogger');
      final List<LogRecord> records = <LogRecord>[];
      testLogger.onRecord.listen(records.add);
      testLogger.info('test message');

      expect(records, isNotEmpty);
      expect(records.first.message, 'test message');
    });

    test('calling initLogging twice does not throw', () {
      initLogging();
      initLogging();
    });
  });

  group('logger name constants', () {
    test('all constants are non-empty strings', () {
      expect(logNameAppPreferences.isNotEmpty, isTrue);
      expect(logNameAppProvider.isNotEmpty, isTrue);
      expect(logNameFileOra.isNotEmpty, isTrue);
      expect(logNameFileTiff.isNotEmpty, isTrue);
      expect(logNameImageHelper.isNotEmpty, isTrue);
      expect(logNameImportFiles.isNotEmpty, isTrue);
      expect(logNameMyWindowManager.isNotEmpty, isTrue);
      expect(logNameDraftRecovery.isNotEmpty, isTrue);
      expect(logNameDraftRecoveryStorage.isNotEmpty, isTrue);
      expect(logNameSave.isNotEmpty, isTrue);
      expect(logNameUndoProvider.isNotEmpty, isTrue);
    });
  });
}
