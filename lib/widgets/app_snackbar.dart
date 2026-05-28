import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/app_progress.dart';

final GlobalKey<NavigatorState> appSnackBarNavigatorKey = GlobalKey<NavigatorState>();
final RegExp _pathSeparatorPattern = RegExp(r'[\\/]');
final TextStyle _snackBarBodyStyle = AppTextStyle.body.copyWith(
  color: AppColors.white,
);
final TextStyle _snackBarTitleStyle = AppTextStyle.bodyBold.copyWith(
  color: AppColors.white,
);
final TextStyle _snackBarSubtitleStyle = AppTextStyle.subtitle.copyWith(
  fontSize: AppFontSize.medium,
);

String _fileNameFromPath(final String path) {
  final List<String> parts = path.split(_pathSeparatorPattern);
  return parts.isEmpty ? path : parts.last;
}

OverlayState? _resolveSnackBarOverlayState(final BuildContext context) {
  return appSnackBarNavigatorKey.currentState?.overlay ?? Overlay.maybeOf(context, rootOverlay: true);
}

BuildContext? _resolveGlobalSnackBarContext() {
  return appSnackBarNavigatorKey.currentContext;
}

/// Builds the text block shown inside snackbar notifications.
Widget _buildSnackBarTextContent(
  final String message, {
  final String? subtitle,
}) {
  if (subtitle == null) {
    return Text(
      message,
      style: _snackBarBodyStyle,
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        message,
        style: _snackBarTitleStyle,
      ),
      const SizedBox(height: AppSpacing.small),
      Text(
        subtitle,
        style: _snackBarSubtitleStyle,
      ),
    ],
  );
}

/// A notification overlay replacing Material [SnackBar] + [ScaffoldMessenger].
///
/// Use [AppNotificationOverlay.show] to display a transient message.
class AppNotificationOverlay {
  AppNotificationOverlay._();

  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  /// Duration before auto-dismissal.
  static const Duration _defaultDuration = Duration(seconds: 4);

  /// Shows a text notification at the bottom of the screen.
  static void show(
    final BuildContext context,
    final String message, {
    final String? subtitle,
    final Duration? duration,
    final bool isProgress = false,
  }) {
    _dismiss();

    final OverlayState? overlayState = _resolveSnackBarOverlayState(context);
    if (overlayState == null) {
      return;
    }

    _activeEntry = OverlayEntry(
      builder: (final BuildContext _) {
        return Positioned(
          bottom: AppSpacing.large,
          left: AppSpacing.large,
          right: AppSpacing.large,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.large,
                  vertical: AppSpacing.big,
                ),
                child: isProgress
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: subtitle == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                        children: <Widget>[
                          const SizedBox.square(
                            dimension: AppLayout.iconSize,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox.square(
                                dimension: AppLayout.loaderRadius,
                                child: AppProgressIndicator(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.big),
                          Flexible(
                            child: _buildSnackBarTextContent(
                              message,
                              subtitle: subtitle,
                            ),
                          ),
                        ],
                      )
                    : _buildSnackBarTextContent(
                        message,
                        subtitle: subtitle,
                      ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_activeEntry!);
    if (isProgress == false) {
      _timer = Timer(duration ?? _defaultDuration, _dismiss);
    }
  }

  /// Dismisses the active notification overlay, if any.
  static void dismiss() {
    _dismiss();
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

/// Shows a notification overlay only when [context] is still mounted.
void showSnackBarIfMounted(
  final BuildContext context,
  final String message, {
  final String? subtitle,
  final Duration? duration,
}) {
  if (!context.mounted) {
    return;
  }

  AppNotificationOverlay.show(
    context,
    message,
    subtitle: subtitle,
    duration: duration,
  );
}

/// Shows a global notification overlay message using the app navigator context.
void showGlobalSnackBarMessage(
  final String message, {
  final String? subtitle,
  final Duration? duration,
}) {
  final BuildContext? context = _resolveGlobalSnackBarContext();
  if (context == null) {
    return;
  }

  AppNotificationOverlay.show(
    context,
    message,
    subtitle: subtitle,
    duration: duration,
  );
}

/// Shows a persistent notification with a progress indicator.
void showGlobalProgressSnackBarMessage(
  final String message, {
  final String? subtitle,
}) {
  final BuildContext? context = _resolveGlobalSnackBarContext();
  if (context == null) {
    return;
  }

  AppNotificationOverlay.show(
    context,
    message,
    subtitle: subtitle,
    isProgress: true,
  );
}

/// Dismisses the active global notification, if any.
void dismissGlobalSnackBarMessage() {
  AppNotificationOverlay.dismiss();
}

/// Runs an asynchronous task while showing global progress feedback.
Future<T> runWithGlobalProgressSnackBar<T>({
  required final Future<T> Function() task,
  required final VoidCallback showInProgress,
  final VoidCallback? showOnSuccess,
}) async {
  showInProgress();

  try {
    final T result = await task();
    if (showOnSuccess != null) {
      showOnSuccess();
    } else {
      dismissGlobalSnackBarMessage();
    }
    return result;
  } catch (_) {
    dismissGlobalSnackBarMessage();
    rethrow;
  }
}

/// Runs a file save task with global saving and saved notifications.
Future<T> runWithGlobalFileSaveSnackBar<T>({
  required final String initialFilePath,
  required final String Function() completedFilePathBuilder,
  required final Future<T> Function() task,
  final Duration? completedDuration,
}) {
  return runWithGlobalProgressSnackBar<T>(
    showInProgress: () {
      showGlobalSavingFileSnackBar(initialFilePath);
    },
    showOnSuccess: () {
      showGlobalSavedFileSnackBar(
        completedFilePathBuilder(),
        duration: completedDuration,
      );
    },
    task: task,
  );
}

/// Shows a persistent save-in-progress notification with the target file name.
void showGlobalSavingFileSnackBar(final String filePath) {
  final BuildContext? context = _resolveGlobalSnackBarContext();
  if (context == null) {
    return;
  }

  showGlobalProgressSnackBarMessage(
    context.l10n.savingLabel,
    subtitle: _fileNameFromPath(filePath),
  );
}

/// Shows a global save confirmation snackbar with the saved file name.
void showGlobalSavedFileSnackBar(
  final String filePath, {
  final Duration? duration,
}) {
  final BuildContext? context = _resolveGlobalSnackBarContext();
  if (context == null) {
    return;
  }

  context.showSavedFileSnackBar(
    filePath,
    duration: duration,
  );
}

/// Convenience extension so any [BuildContext] can show a notification overlay.
extension AppSnackBarBuildContextX on BuildContext {
  /// Shows a notification overlay message if the context is still mounted.
  void showSnackBarMessage(
    final String message, {
    final String? subtitle,
    final Duration? duration,
  }) {
    showSnackBarIfMounted(
      this,
      message,
      subtitle: subtitle,
      duration: duration,
    );
  }

  /// Shows a save confirmation snackbar with the saved file name as subtitle.
  void showSavedFileSnackBar(
    final String filePath, {
    final Duration? duration,
  }) {
    showSnackBarMessage(
      l10n.savedLabel,
      subtitle: _fileNameFromPath(filePath),
      duration: duration,
    );
  }
}
