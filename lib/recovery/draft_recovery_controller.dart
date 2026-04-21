import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/recovery/draft_recovery_storage.dart';
import 'package:fpaint/recovery/draft_recovery_storage_io.dart'
    if (dart.library.html) 'package:fpaint/recovery/draft_recovery_storage_web.dart'
    as draft_storage;
import 'package:logging/logging.dart';

typedef DraftRecoveryEncoder = Future<List<int>> Function(LayersProvider layers);
typedef DraftRecoveryRestorer = Future<void> Function(LayersProvider layers, Uint8List bytes);

final Logger _log = Logger(logNameDraftRecovery);

/// Manages autosave snapshots and restoration of unsaved draft artwork.
class DraftRecoveryController with WidgetsBindingObserver {
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
  Future<void> flushNow() async {
    _saveTimer?.cancel();
    await _reconcileDraft();
  }

  /// Prompts the user to restore a stored draft and applies it when accepted.
  Future<void> maybeRestoreDraft({
    required final BuildContext context,
    required final AppProvider appProvider,
  }) async {
    if (await _storage.hasDraft() == false || context.mounted == false) {
      if (await _storage.hasDraft() == false) {
        await preferences.clearRecoveryDraftSourceFilePath();
      }
      return;
    }

    final AppLocalizations l10n = context.l10n;
    final bool shouldRestore =
        await showDialog<bool>(
          context: context,
          builder: (final BuildContext dialogContext) {
            return AlertDialog(
              title: Text(l10n.restoreRecoveryDraftTitle),
              content: Text(l10n.restoreRecoveryDraftMessage),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.discardRecoveryDraft),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.restoreRecoveryDraft),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldRestore == false) {
      await discardDraft();
      return;
    }

    final Uint8List? bytes = await _storage.readDraft();
    if (bytes == null || bytes.isEmpty) {
      await discardDraft();
      return;
    }

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
      if (context.mounted) {
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
          await preferences.setRecoveryDraftSourceFilePath(_currentSourceFilePath);
        } else {
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
