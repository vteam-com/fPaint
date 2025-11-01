import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// Window management utilities for the fPaint application.
///
/// This class handles window positioning, sizing, and state persistence
/// across application sessions. It provides platform-specific optimizations
/// and integration test support.
///
/// Dependencies required:
/// - shared_preferences: ^2.5.3
/// - window_manager: ^0.5.0
class MyWindowManager extends WindowListener {
  /// Checks if the app is running in integration test mode.
  ///
  /// Returns true if the current runtime type indicates integration testing.
  static bool _isIntegrationTest() {
    return WidgetsBinding.instance.runtimeType.toString().contains('IntegrationTest');
  }

  /// Sets up the main application window with platform-specific optimizations.
  ///
  /// This method configures:
  /// - Impeller rendering engine for mobile platforms
  /// - Window manager for desktop platforms
  /// - System UI mode for edge-to-edge display
  /// - Window state restoration
  ///
  /// Does nothing on web platforms.
  static Future<void> setupMainWindow() async {
    if (!kIsWeb) {
      // Enable Impeller for better performance
      // This reduces shader compilation jank on mobile platforms
      if (Platform.isIOS || Platform.isAndroid) {
        // Impeller is enabled by default on iOS, but we can explicitly set it
        // For Android, we need to opt-in
        PlatformDispatcher.instance.onError = (final Object error, final StackTrace stack) {
          // Log any Impeller-related errors
          if (kDebugMode) {
            print('Unhandled error: $error');
          }
          return true;
        };
        // Only enable system UI mode for iOS/Android.
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        await windowManager.ensureInitialized();

        // Tell window_manager we want to intercept close
        await windowManager.setPreventClose(true);

        windowManager.addListener(MyWindowManager());

        await MyWindowManager.restoreWindowState();
      }
    }
  }

  /// Saves the current window state to persistent storage.
  ///
  /// Stores the window position (x, y) and size (width, height) in SharedPreferences
  /// so it can be restored in future application sessions.
  static Future<void> saveWindowState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Rect bounds = await windowManager.getBounds();

    await prefs.setDouble('window_x', bounds.left);
    await prefs.setDouble('window_y', bounds.top);
    await prefs.setDouble('window_width', bounds.width);
    await prefs.setDouble('window_height', bounds.height);
  }

  /// Restores the window state from persistent storage.
  ///
  /// Retrieves previously saved window bounds and applies them. If no saved state
  /// exists, sets up default window sizing based on whether integration tests
  /// are running. Centers the window and ensures it's visible and focused.
  static Future<void> restoreWindowState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final bool hasData =
        prefs.containsKey('window_x') &&
        prefs.containsKey('window_y') &&
        prefs.containsKey('window_width') &&
        prefs.containsKey('window_height');

    if (hasData) {
      final double x = MyWindowManager.getSafeDouble(prefs, 'window_x')!;
      final double y = MyWindowManager.getSafeDouble(prefs, 'window_y')!;
      final double width = MyWindowManager.getSafeDouble(prefs, 'window_width')!;
      final double height = MyWindowManager.getSafeDouble(prefs, 'window_height')!;

      await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
    } else {
      // Set integration test window size if running integration tests
      if (_isIntegrationTest()) {
        await windowManager.setSize(const Size(1200, 900));
      } else {
        // Optional: set a default window size
        // await windowManager.setSize(const Size(800, 600));
      }
      await windowManager.center();
    }

    await windowManager.show();
    await windowManager.focus();
  }

  /// Safely retrieves a double value from SharedPreferences.
  ///
  /// Handles type conversion from int to double for backward compatibility.
  /// Returns null if the key doesn't exist or contains an incompatible type.
  ///
  /// [prefs] The SharedPreferences instance to read from.
  /// [key] The key to retrieve the value for.
  /// Returns the double value, or null if not found or incompatible.
  static double? getSafeDouble(final SharedPreferences prefs, final String key) {
    final Object? value = prefs.get(key);
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble(); // gracefully convert
    }
    return null;
  }

  /// Handles window close events to ensure proper cleanup.
  ///
  /// Saves the window state before allowing the window to close.
  /// This ensures that window position and size are preserved for the next session.
  @override
  Future<void> onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // Prevent the close, do your save logic first
      await saveWindowState();

      // Then actually destroy the window
      await windowManager.destroy();
    }
  }
}
