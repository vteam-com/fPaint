import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/main_screen.dart';
import 'package:fpaint/my_window_manager.dart';
import 'package:fpaint/pages/platforms_page.dart';
import 'package:fpaint/pages/settings_page.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/shortcuts.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// The global instance of the [MyApp] widget.
///
/// This variable is initialized in the [main] function and used to access the app's providers.
late MyApp mainApp;

/// The main function is the entry point of the Flutter application.
///
/// It initializes the Flutter widgets, sets up the system UI mode,
/// handles file opening events, and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MyWindowManager.setupMainWindow();
  mainApp = MyApp();

  // Platform channel for file opening.
  const MethodChannel('com.vteam.fpaint/file').setMethodCallHandler((final MethodCall call) async {
    if (call.method == 'fileOpened') {
      final String filePath = call.arguments as String;

      // Check if there are unsaved changes before clearing
      if (mainApp.appProvider.layers.hasChanged) {
        final bool shouldProceed =
            await showDialog<bool>(
              context: mainApp.navigatorKey.currentContext!,
              builder: (final BuildContext context) {
                final AppLocalizations l10n = AppLocalizations.of(context)!;

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
  });

  runApp(mainApp);
}

/// The main entry point for the Flutter Paint App.
///
/// This class sets up the app's theme, keyboard shortcuts, and actions for undo, redo, and saving the file.
/// The [MainScreen] widget is the root of the app's UI.
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget.
  MyApp({super.key});

  /// Provides application-level functionalities and states.
  final AppProvider appProvider = AppProvider();

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
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => shellProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => appProvider),
        // The layers provider is a shared singleton; provide the existing
        // instance without transferring disposal ownership to Provider.
        ChangeNotifierProvider<LayersProvider>.value(value: layersProvider),
        // ignore: always_specify_types
        ChangeNotifierProvider(create: (final BuildContext _) => undoProvider),
      ],
      child: Consumer<AppProvider>(
        builder: (final BuildContext _, final AppProvider currentAppProvider, final Widget? _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: appName,
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: currentAppProvider.preferredLocale,
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
          );
        },
      ),
    );
  }
}
