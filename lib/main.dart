import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/my_window_manager.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/recovery/draft_recovery_controller.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:provider/single_child_widget.dart';

const String _clearPendingFileMethod = 'clearPendingFile';
const String _fileChannelName = 'com.vteam.fpaint/file';
const String _fileOpenedMethod = 'fileOpened';
const String _fileUrlPrefix = 'file://';
const String _getPendingFileMethod = 'getPendingFile';
const MethodChannel _fileChannel = MethodChannel(_fileChannelName);

/// The global instance of the [MyApp] widget.
///
/// This variable is initialized in the [main] function and used to access the app's providers.
late MyApp mainApp;

String? _queuedPlatformFilePath;
bool _isProcessingQueuedPlatformFile = false;
bool _platformFileHandlingReady = false;

/// The main function is the entry point of the Flutter application.
///
/// It initializes the Flutter widgets, sets up the system UI mode,
/// handles file opening events, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging();

  await MyWindowManager.setupMainWindow();
  mainApp = MyApp();
  await mainApp.draftRecoveryController.initialize();

  // Platform channel for file opening.
  _fileChannel.setMethodCallHandler((final MethodCall call) async {
    if (call.method == _fileOpenedMethod) {
      final String filePath = _normalizePlatformFilePath(call.arguments as String);
      await _queueOrHandlePlatformFile(filePath);
    }
  });

  runApp(mainApp);

  // After the app is running, check for a file that was pending at launch.
  WidgetsBinding.instance.addPostFrameCallback((final _) async {
    String? pendingFile;

    try {
      pendingFile = await _fileChannel.invokeMethod<String>(_getPendingFileMethod);
    } on MissingPluginException {
      pendingFile = null;
    } on PlatformException {
      pendingFile = null;
    }

    final String? startupFilePath =
        _queuedPlatformFilePath ?? (pendingFile == null ? null : _normalizePlatformFilePath(pendingFile));
    _queuedPlatformFilePath = null;

    _platformFileHandlingReady = true;

    if (startupFilePath == null || startupFilePath.isEmpty) {
      await mainApp.draftRecoveryController.restoreDraftIfAvailable(
        appProvider: mainApp.appProvider,
      );
    }

    if (startupFilePath != null && startupFilePath.isNotEmpty) {
      _queuedPlatformFilePath = startupFilePath;
      _scheduleQueuedPlatformFileHandling();
      return;
    }

    _scheduleQueuedPlatformFileHandling();
  });
}

Future<void> _queueOrHandlePlatformFile(final String filePath) async {
  if (_platformFileHandlingReady == false || mainApp.navigatorKey.currentContext == null) {
    _queuedPlatformFilePath = filePath;
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
  if (_queuedPlatformFilePath == null || _isProcessingQueuedPlatformFile) {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((final _) async {
    if (_queuedPlatformFilePath == null || _isProcessingQueuedPlatformFile) {
      return;
    }

    if (_platformFileHandlingReady == false || mainApp.navigatorKey.currentContext == null) {
      _scheduleQueuedPlatformFileHandling();
      return;
    }

    final String filePath = _queuedPlatformFilePath!;
    _queuedPlatformFilePath = null;
    _isProcessingQueuedPlatformFile = true;

    try {
      await _consumePlatformFile(filePath);
    } finally {
      _isProcessingQueuedPlatformFile = false;
      if (_queuedPlatformFilePath != null) {
        _scheduleQueuedPlatformFileHandling();
      }
    }
  });
}

/// Processes a platform-provided file path and clears the native pending state.
///
/// This keeps the Flutter and native sides in sync so repeated launches do not
/// reuse a path that has already been handled.
Future<void> _consumePlatformFile(final String filePath) async {
  try {
    await _handleFileOpened(filePath);
  } finally {
    if (_queuedPlatformFilePath == filePath) {
      _queuedPlatformFilePath = null;
    }
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

/// Converts a platform-supplied file URL into a local file path when needed.
///
/// Finder and other macOS entry points may send a `file://` URL instead of a
/// plain path, so this normalizes both representations for the file loaders.
String _normalizePlatformFilePath(final String filePathOrUrl) {
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
Future<void> _handleFileOpened(final String filePath) async {
  // Check if there are unsaved changes before clearing
  if (mainApp.appProvider.layers.hasChanged) {
    final bool shouldProceed =
        await showDialog<bool>(
          context: mainApp.navigatorKey.currentContext!,
          builder: (final BuildContext context) {
            final AppLocalizations l10n = context.l10n;

            return AlertDialog(
              title: Text(l10n.unsavedChanges),
              content: Text(l10n.unsavedChangesDiscardAndOpenPrompt),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.discardAndOpen),
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

  mainApp.appProvider.layers.clear();
  final bool success = await openFileFromPath(
    context: mainApp.navigatorKey.currentContext!,
    layers: mainApp.appProvider.layers,
    path: filePath,
  );

  // Update the shell provider with the file name if successful
  if (success) {
    mainApp.shellProvider.loadedFileName = filePath;
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
  late final AppProvider appProvider = AppProvider(preferences: appPreferences);

  /// Manages autosave snapshots and startup draft recovery.
  late final DraftRecoveryController draftRecoveryController = DraftRecoveryController(
    preferences: appPreferences,
    layers: layersProvider,
    shellProvider: shellProvider,
  );

  /// Provides functionalities and states for managing layers.
  final LayersProvider layersProvider = LayersProvider();

  /// Global navigator key to access context from outside of the widget tree
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Provides shell-level functionalities and states.
  final ShellProvider shellProvider = ShellProvider();

  /// Provides functionalities for undo and redo operations.
  final UndoProvider undoProvider = UndoProvider();
  @override
  Widget build(final BuildContext context) {
    final BorderSide popupBorder = BorderSide(
      color: Colors.white.withValues(alpha: AppVisual.popupBorderAlpha),
      width: AppStroke.thin,
    );

    final RoundedRectangleBorder popupShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: popupBorder,
    );

    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<DraftRecoveryController>.value(value: draftRecoveryController),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => shellProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => appPreferences),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => appProvider),
        // The layers provider is a shared singleton; provide the existing
        // instance without transferring disposal ownership to Provider.
        ChangeNotifierProvider<LayersProvider>.value(value: layersProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => undoProvider),
      ],
      child: Consumer2<AppProvider, AppPreferences>(
        builder:
            (
              final BuildContext _,
              final AppProvider currentAppProvider,
              final AppPreferences currentPreferences,
              final Widget? _,
            ) {
              return RepaintBoundary(
                key: Keys.appScreenshotBoundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorKey: navigatorKey,
                  title: appName,
                  localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  locale: currentPreferences.preferredLocale,
                  localeResolutionCallback: (final Locale? locale, final Iterable<Locale> supportedLocales) {
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
                  theme: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      secondary: AppColors.secondary,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: AppColors.surface,
                      shape: popupShape,
                    ),
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppColors.surface,
                      shape: popupShape,
                    ),
                    bottomSheetTheme: BottomSheetThemeData(
                      backgroundColor: AppColors.surface,
                      modalBackgroundColor: AppColors.surface,
                      shape: popupShape,
                    ),
                    sliderTheme: SliderThemeData(
                      activeTrackColor: AppColors.secondary,
                      inactiveTrackColor: AppColors.surfaceVariant,
                      thumbColor: AppColors.accent,
                      overlayColor: AppColors.primary.withAlpha(AppLimits.percentMax),
                    ),
                  ),
                  routes: <String, WidgetBuilder>{
                    '/': (final BuildContext context) => shortCutsForMainApp(
                      context,
                      shellProvider,
                      currentAppProvider,
                      const MainScreen(),
                    ),
                    '/settings': (final _) => const SettingsPage(),
                    '/platforms': (final _) => const PlatformsPage(),
                  },
                ),
              );
            },
      ),
    );
  }
}
