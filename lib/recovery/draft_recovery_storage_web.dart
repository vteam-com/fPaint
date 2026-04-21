import 'dart:typed_data';

import 'package:fpaint/recovery/draft_recovery_storage.dart';

/// Creates the no-op recovery storage used on web builds.
DraftRecoveryStorage createDraftRecoveryStorage() {
  return const _WebDraftRecoveryStorage();
}

class _WebDraftRecoveryStorage implements DraftRecoveryStorage {
  const _WebDraftRecoveryStorage();

  @override
  Future<void> deleteDraft() async {}

  @override
  Future<bool> hasDraft() async {
    return false;
  }

  @override
  Future<Uint8List?> readDraft() async {
    return null;
  }

  @override
  Future<void> writeDraft(final Uint8List bytes) async {}
}
