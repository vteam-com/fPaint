import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/draft_recovery_encoder.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/files/quit_confirmation.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/helpers/trackpad_pressure.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/inherited_provider.dart' show InheritedControllerScope;
import 'package:fpaint/providers/inherited_scope.dart';
import 'package:fpaint/providers/security_scoped_file_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/shortcuts.dart';

const String _clearPendingFileMethod = 'clearPendingFile';
const String _editChannelName = 'com.vteam.fpaint/edit';
const String _editRedoMethod = 'redo';
const String _editUndoMethod = 'undo';
const String _fileChannelName = 'com.vteam.fpaint/file';
const String _fileOpenedMethod = 'fileOpened';
const String _fileUrlPrefix = 'file://';
const String _getPendingFileMethod = 'getPendingFile';
const MethodChannel _editChannel = MethodChannel(_editChannelName);
const MethodChannel _fileChannel = MethodChannel(_fileChannelName);

/// The global instance of the [MyApp] widget.
///
/// This variable is initialized in the [main] function and used to access the app's providers.
late MyApp mainApp;

final List<String> _queuedPlatformFilePaths = <String>[];
bool _isProcessingQueuedPlatformFile = false;
bool _platformFileHandlingReady = false;

/// Queues a file the platform asked the app to open (Finder, Explorer, share
/// sheet), so several files opened at once are processed one at a time.
///
/// A path already waiting is not queued again: at launch the same file can
/// arrive both as a `fileOpened` call and as the pending file.
void queuePlatformFileForProcessing(String filePath) {
  if (_queuedPlatformFilePaths.contains(filePath)) {
    return;
  }
  _queuedPlatformFilePaths.add(filePath);
}

/// Removes and returns the oldest queued platform file path, or null when the
/// queue is empty.
String? dequeueQueuedPlatformFile() {
  if (_queuedPlatformFilePaths.isEmpty) {
    return null;
  }

  return _queuedPlatformFilePaths.removeAt(0);
}

/// The main function is the entry point of the Flutter application.
///
/// It initializes the Flutter widgets, sets up the system UI mode,
/// handles file opening events, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  mainApp = MyApp();
  await mainApp.draftRecoveryController.initialize();

  // Platform channel for file opening.
  _fileChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == _fileOpenedMethod) {
      final String filePath = _normalizePlatformFilePath(call.arguments as String);
      await _queueOrHandlePlatformFile(filePath);
      return null;
    }

    if (call.method == quitRequestedMethod) {
      return confirmQuitWithUnsavedChanges(
        layers: mainApp.appProvider.layers,
        context: mainApp.navigatorKey.currentContext,
      );
    }

    return null;
  });
  _editChannel.setMethodCallHandler(handlePlatformEditMethodCall);
  TrackpadPressure.instance.listen();

  runApp(mainApp);

  // After the app is running, check for a file that was pending at launch.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    String? pendingFile;

    try {
      pendingFile = await _fileChannel.invokeMethod<String>(_getPendingFileMethod);
    } on MissingPluginException {
      pendingFile = null;
    } on PlatformException {
      pendingFile = null;
    }

    final String? startupFilePath = pendingFile == null ? null : _normalizePlatformFilePath(pendingFile);

    if (startupFilePath != null && startupFilePath.isNotEmpty) {
      queuePlatformFileForProcessing(startupFilePath);
    }

    _platformFileHandlingReady = true;

    if (_queuedPlatformFilePaths.isEmpty) {
      await mainApp.draftRecoveryController.restoreDraftIfAvailable(
        appProvider: mainApp.appProvider,
      );
    }

    _scheduleQueuedPlatformFileHandling();
  });
}

Future<void> _queueOrHandlePlatformFile(String filePath) async {
  if (_platformFileHandlingReady == false || mainApp.navigatorKey.currentContext == null) {
    queuePlatformFileForProcessing(filePath);
    _scheduleQueuedPlatformFileHandling();
    return;
  }

  await _consumePlatformFile(filePath);
}

/// Schedules queued platform file handling for the next frame.
///
/// This defers file processing until the navigator context exists and ensures
/// only one queued file is being processed at a time.
void _scheduleQueuedPlatformFileHandling() {
  if (_queuedPlatformFilePaths.isEmpty || _isProcessingQueuedPlatformFile) {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (_queuedPlatformFilePaths.isEmpty || _isProcessingQueuedPlatformFile) {
      return;
    }

    if (_platformFileHandlingReady == false || mainApp.navigatorKey.currentContext == null) {
      _scheduleQueuedPlatformFileHandling();
      return;
    }

    final String? filePath = dequeueQueuedPlatformFile();
    if (filePath == null) {
      return;
    }
    _isProcessingQueuedPlatformFile = true;

    try {
      await _consumePlatformFile(filePath);
    } finally {
      _isProcessingQueuedPlatformFile = false;
      if (_queuedPlatformFilePaths.isNotEmpty) {
        _scheduleQueuedPlatformFileHandling();
      }
    }
  });
}

/// Processes a platform-provided file path and clears the native pending state.
///
/// This keeps the Flutter and native sides in sync so repeated launches do not
/// reuse a path that has already been handled.
Future<void> _consumePlatformFile(String filePath) async {
  try {
    await _handleFileOpened(filePath);
  } finally {
    await _clearPendingPlatformFile();
  }
}

Future<void> _clearPendingPlatformFile() async {
  try {
    await _fileChannel.invokeMethod<void>(_clearPendingFileMethod);
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

/// Handles native platform edit commands that need to trigger Flutter actions.
@visibleForTesting
Future<void> handlePlatformEditMethodCall(MethodCall call) async {
  switch (call.method) {
    case _editUndoMethod:
      await mainApp.appProvider.undoAction();
      return;
    case _editRedoMethod:
      await mainApp.appProvider.redoAction();
      return;
    default:
      throw MissingPluginException('Unhandled edit command: ${call.method}');
  }
}

/// Converts a platform-supplied file URL into a local file path when needed.
///
/// Finder and other macOS entry points may send a `file://` URL instead of a
/// plain path, so this normalizes both representations for the file loaders.
String _normalizePlatformFilePath(String filePathOrUrl) {
  if (filePathOrUrl.startsWith(_fileUrlPrefix) == false) {
    return filePathOrUrl;
  }

  try {
    return Uri.parse(filePathOrUrl).toFilePath();
  } on FormatException {
    return filePathOrUrl;
  }
}

/// Handles a file opened from the platform (e.g. double-click in Finder).
Future<void> _handleFileOpened(String filePath) async {
  // Check if there are unsaved changes before clearing
  if (mainApp.appProvider.layers.hasChanged) {
    final bool shouldProceed =
        await showAppDialog<bool>(
          context: mainApp.navigatorKey.currentContext!,
          builder: (BuildContext context) {
            final AppLocalizations l10n = context.l10n;

            return AppDialog(
              title: l10n.unsavedChanges,
              content: AppText(l10n.unsavedChangesDiscardAndOpenPrompt),
              actions: <Widget>[
                AppRowSecondaryButton(
                  onPressed: () => Navigator.pop(context, false),
                  text: l10n.cancel,
                ),
                AppRowDangerButton(
                  onPressed: () => Navigator.pop(context, true),
                  text: l10n.discardAndOpen,
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldProceed) {
      return;
    }
  }

  // An iOS document opened in place from the Files app comes with a bookmark;
  // opening through it grants access, and keeping it lets Save write back.
  final String? bookmark = await SecurityScopedFileService.openedFileBookmark(filePath);
  mainApp.appProvider.layers.clear();
  final bool success = await SecurityScopedFileService.withResolvedBookmark<bool>(
    bookmarkBase64: bookmark,
    fallbackPath: filePath,
    action: (String resolvedPath) => openFileFromPath(
      context: mainApp.navigatorKey.currentContext!,
      layers: mainApp.appProvider.layers,
      path: resolvedPath,
    ),
  );

  // Update the shell provider with the file name if successful
  if (success) {
    mainApp.shellProvider.loadedFileName = filePath;
    await AppPreferences.of(
      mainApp.navigatorKey.currentContext!,
    ).addRecentFile(filePath, bookmark: bookmark);
  }
}

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget.
  MyApp({super.key});

  /// Provides application preferences and persisted UI settings.
  final AppPreferences appPreferences = AppPreferences();

  /// Provides application-level functionalities and states.
  late final AppProvider appProvider = AppProvider(
    preferences: appPreferences,
    layersProvider: layersProvider,
    undoProvider: undoProvider,
  );

  /// Manages autosave snapshots and startup draft recovery.
  late final DraftRecoveryController draftRecoveryController = DraftRecoveryController(
    preferences: appPreferences,
    layers: layersProvider,
    shellProvider: shellProvider,
    encoder: createRecoveryDraft,
    restorer: restoreRecoveryDraft,
  );

  /// Provides functionalities and states for managing layers.
  late final LayersProvider layersProvider = LayersProvider(undoProvider: undoProvider);

  /// Global navigator key to access context from outside of the widget tree
  final GlobalKey<NavigatorState> navigatorKey = appSnackBarNavigatorKey;

  /// Provides shell-level functionalities and states.
  final ShellProvider shellProvider = ShellProvider();

  /// Provides functionalities for undo and redo operations.
  final UndoProvider undoProvider = UndoProvider();
  @override
  Widget build(BuildContext context) {
    return InheritedScope<DraftRecoveryController>(
      controller: draftRecoveryController,
      child: InheritedControllerScope<ShellProvider>(
        controller: shellProvider,
        child: InheritedControllerScope<AppPreferences>(
          controller: appPreferences,
          child: InheritedControllerScope<AppProvider>(
            controller: appProvider,
            child: InheritedControllerScope<LayersProvider>(
              controller: layersProvider,
              child: InheritedControllerScope<UndoProvider>(
                controller: undoProvider,
                child: ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[appProvider, appPreferences]),
                  builder: (BuildContext _, Widget? _) {
                    return RepaintBoundary(
                      key: Keys.appScreenshotBoundary,
                      child: WidgetsApp(
                        debugShowCheckedModeBanner: false,
                        navigatorKey: navigatorKey,
                        title: appName,
                        color: AppColors.primary,
                        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
                          return PageRouteBuilder<T>(
                            settings: settings,
                            pageBuilder: (
                              BuildContext context,
                              Animation<double> _,
                              Animation<double> _,
                            ) => builder(context),
                          );
                        },
                        localizationsDelegates: AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        locale: appPreferences.preferredLocale,
                        localeResolutionCallback: (Locale? locale, Iterable<Locale> supportedLocales) {
                          if (locale == null) {
                            return const Locale('en');
                          }

                          for (final Locale supportedLocale in supportedLocales) {
                            if (supportedLocale.languageCode == locale.languageCode) {
                              return supportedLocale;
                            }
                          }

                          return const Locale('en');
                        },
                        routes: <String, WidgetBuilder>{
                          '/': (BuildContext context) => shortCutsForMainApp(
                            context,
                            shellProvider,
                            appProvider,
                            const MainScreen(),
                            onSave: () async {
                              await runWithGlobalFileSaveSnackBar<void>(
                                initialFilePath: shellProvider.loadedFileName,
                                completedFilePathBuilder: () => shellProvider.loadedFileName,
                                task: () {
                                  return saveFile(
                                    shellProvider,
                                    appProvider.layers,
                                    appPreferences,
                                  );
                                },
                              );
                            },
                          ),
                          '/settings': (_) => const SettingsPage(),
                          '/platforms': (_) => const PlatformsPage(),
                        },
                        builder: (BuildContext _, Widget? child) {
                          return DefaultTextStyle(
                            style: const TextStyle(fontFamily: appFontFamily),
                            child: child ?? const SizedBox.shrink(),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
