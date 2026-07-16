import 'dart:typed_data';

import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/providers/app_provider.dart';

/// Creates an ORA archive from the current layers for recovery backup.
Future<List<int>> createRecoveryDraft(final LayersProvider layers) {
  return createOraArchive(
    layers,
    includePreviews: false,
  );
}

/// Restores layers from recovery draft bytes.
Future<void> restoreRecoveryDraft(
  final LayersProvider layers,
  final Uint8List bytes,
) {
  return readOraFileFromBytes(layers, bytes);
}
