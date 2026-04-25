import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/draft_flusher.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:fpaint/recovery/draft_recovery_storage_io.dart'
    if (dart.library.html) 'package:fpaint/recovery/draft_recovery_storage_web.dart'
    as draft_storage;
import 'package:fpaint/widgets/material_free/app_snackbar.dart';
import 'package:logging/logging.dart';

typedef DraftRecoveryEncoder = Future<List<int>> Function(LayersProvider layers);
typedef DraftRecoveryRestorer = Future<void> Function(LayersProvider layers, Uint8List bytes);

final Logger _log = Logger(logNameDraftRecovery);

/// Manages autosave snapshots and restoration of unsaved draft artwork.
class DraftRecoveryController with WidgetsBindingObserver implements DraftFlusher {
  /// Creates a [DraftRecoveryController].
  DraftRecoveryController({
    required this.preferences,
    required this.layers,
    required this.shellProvider,
    DraftRecoveryStorage? storage,
    DraftRecoveryEncoder? encoder,
    DraftRecoveryRestorer? restorer,
    Duration? saveDebounce,
  }) : _storage = storage ?? draft_storage.createDraftRecoveryStorage(),
       _encoder = encoder ?? _defaultDraftRecoveryEncoder,
       _restorer = restorer ?? _defaultDraftRecoveryRestorer,
       _saveDebounce = saveDebounce ?? AppDefaults.recoverySaveDebounce;

  final AppPreferences preferences;
  final LayersProvider layers;
  final ShellProvider shellProvider;
  final DraftRecoveryStorage _storage;
  final DraftRecoveryEncoder _encoder;
  final DraftRecoveryRestorer _restorer;
  final Duration _saveDebounce;

  Timer? _saveTimer;
  bool _isInitialized = false;
  bool _isReconciling = false;
  bool _needsReconcile = false;
  bool _isDisposed = false;
  bool _isStartupRecoveryCheckPending = true;
  bool _hasWrittenDraftThisSession = false;

  /// Starts listening for layer changes and lifecycle events.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    await preferences.getPref();
    WidgetsBinding.instance.addObserver(this);
    layers.addListener(_handleLayersChanged);
    _isInitialized = true;
  }

  /// Stops listening for changes and cancels any pending autosave timer.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _saveTimer?.cancel();
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      layers.removeListener(_handleLayersChanged);
    }
    _isDisposed = true;
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flushNow());
    }
  }

  /// Saves or clears the recovery draft immediately without waiting for debounce.
  @override
  Future<void> flushNow() async {
    _saveTimer?.cancel();
    await _reconcileDraft();
  }

  /// Restores a stored draft automatically when one is available.
  Future<void> restoreDraftIfAvailable({
    required final AppProvider appProvider,
  }) async {
    try {
      final bool hasDraft = await _storage.hasDraft();
      if (hasDraft == false) {
        await preferences.clearRecoveryDraftSourceFilePath();
        return;
      }

      final Uint8List? bytes = await _storage.readDraft();
      if (bytes == null || bytes.isEmpty) {
        _log.warning('Draft bytes were null or empty, discarding');
        await discardDraft();
        return;
      }

      await _restoreDraft(
        appProvider: appProvider,
        bytes: bytes,
      );
    } finally {
      _isStartupRecoveryCheckPending = false;
    }
  }

  /// Applies draft bytes to the in-memory document and resets view state.
  ///
  /// If [context] is provided, restoration failures are surfaced to users via
  /// a localized snackbar message before discarding the unreadable draft.
  Future<void> _restoreDraft({
    required final AppProvider appProvider,
    required final Uint8List bytes,
    final BuildContext? context,
  }) async {
    try {
      final String? sourceFilePath = await preferences.getRecoveryDraftSourceFilePath();
      layers.clear();
      await _restorer(layers, bytes);
      layers.markAllChanged();
      shellProvider.loadedFileName = sourceFilePath ?? '';
      shellProvider.update();
      appProvider.resetView();
      appProvider.update();
    } catch (error, stackTrace) {
      _log.severe('Failed to restore recovery draft.', error, stackTrace);
      if (context != null && context.mounted) {
        context.showSnackBarMessage(
          context.l10n.errorProcessingFile(error.toString()),
        );
      }
      await discardDraft();
    }
  }

  /// Deletes the stored draft and clears its associated source file metadata.
  Future<void> discardDraft() async {
    _saveTimer?.cancel();
    await _storage.deleteDraft();
    await preferences.clearRecoveryDraftSourceFilePath();
  }

  /// Debounces layer changes so recovery snapshots are written at a steady rate.
  void _handleLayersChanged() {
    if (_isDisposed) {
      return;
    }

    _saveTimer?.cancel();
    if (_saveDebounce == Duration.zero || layers.hasChanged == false) {
      unawaited(_reconcileDraft());
      return;
    }

    _saveTimer = Timer(_saveDebounce, () {
      unawaited(_reconcileDraft());
    });
  }

  /// Synchronizes persisted recovery state with the current dirty-document state.
  Future<void> _reconcileDraft() async {
    if (_isReconciling) {
      _needsReconcile = true;
      return;
    }

    _isReconciling = true;
    try {
      do {
        _needsReconcile = false;
        if (layers.hasChanged) {
          final Uint8List bytes = Uint8List.fromList(await _encoder(layers));
          await _storage.writeDraft(bytes);
          _hasWrittenDraftThisSession = true;
          await preferences.setRecoveryDraftSourceFilePath(_currentSourceFilePath);
        } else {
          if (_isStartupRecoveryCheckPending && _hasWrittenDraftThisSession == false) {
            continue;
          }
          await _storage.deleteDraft();
          await preferences.clearRecoveryDraftSourceFilePath();
        }
      } while (_needsReconcile);
    } catch (error, stackTrace) {
      _log.warning('Failed to reconcile recovery draft.', error, stackTrace);
    } finally {
      _isReconciling = false;
    }
  }

  String? get _currentSourceFilePath {
    final String sourceFilePath = shellProvider.loadedFileName.trim();
    if (sourceFilePath.isEmpty) {
      return null;
    }

    return sourceFilePath;
  }
}

Future<List<int>> _defaultDraftRecoveryEncoder(final LayersProvider layers) {
  return createOraArchive(layers);
}

Future<void> _defaultDraftRecoveryRestorer(
  final LayersProvider layers,
  final Uint8List bytes,
) {
  return readOraFileFromBytes(layers, bytes);
}
