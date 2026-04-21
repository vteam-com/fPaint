import 'dart:typed_data';

/// Persists a single recovery draft snapshot for the current document.
abstract class DraftRecoveryStorage {
  /// Returns whether a recovery draft is currently stored.
  Future<bool> hasDraft();

  /// Reads the stored recovery draft bytes, or returns null when none exist.
  Future<Uint8List?> readDraft();

  /// Writes the latest recovery draft bytes, replacing any previous snapshot.
  Future<void> writeDraft(Uint8List bytes);

  /// Removes any stored recovery draft snapshot.
  Future<void> deleteDraft();
}
