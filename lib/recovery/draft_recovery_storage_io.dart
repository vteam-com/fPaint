import 'dart:io';
import 'dart:typed_data';

import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

const String _draftRecoveryDirectoryName = 'draft_recovery';
const String _draftRecoveryFileName = 'recovery.ora';

final Logger _log = Logger(logNameDraftRecoveryStorage);

/// Creates the file-backed recovery storage used on non-web platforms.
DraftRecoveryStorage createDraftRecoveryStorage() {
  return _IoDraftRecoveryStorage();
}

class _IoDraftRecoveryStorage implements DraftRecoveryStorage {
  @override
  Future<void> deleteDraft() async {
    final File draftFile = await _getDraftFile();
    if (await draftFile.exists()) {
      await draftFile.delete();
    }
  }

  @override
  Future<bool> hasDraft() async {
    final File draftFile = await _getDraftFile();
    return draftFile.exists();
  }

  @override
  Future<Uint8List?> readDraft() async {
    final File draftFile = await _getDraftFile();
    if (await draftFile.exists() == false) {
      return null;
    }

    try {
      return draftFile.readAsBytes();
    } catch (e) {
      _log.severe('Error reading draft file: ${draftFile.path}', e);
      rethrow;
    }
  }

  @override
  Future<void> writeDraft(final Uint8List bytes) async {
    final File draftFile = await _getDraftFile();
    try {
      await draftFile.writeAsBytes(bytes, flush: true);
    } catch (e) {
      _log.severe('Error writing draft file: ${draftFile.path}', e);
      rethrow;
    }
  }

  /// Returns the application-support directory reserved for recovery drafts.
  Future<Directory> _getDraftDirectory() async {
    final Directory appSupportDirectory = await getApplicationSupportDirectory();
    final Directory draftDirectory = Directory(
      '${appSupportDirectory.path}/$_draftRecoveryDirectoryName',
    );

    if (await draftDirectory.exists() == false) {
      await draftDirectory.create(recursive: true);
    }

    return draftDirectory;
  }

  Future<File> _getDraftFile() async {
    final Directory draftDirectory = await _getDraftDirectory();
    return File('${draftDirectory.path}/$_draftRecoveryFileName');
  }
}
