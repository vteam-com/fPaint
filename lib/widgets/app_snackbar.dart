import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

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
    final Duration? duration,
  }) {
    _dismiss();

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
                child: Text(
                  message,
                  style: AppTextStyle.body,
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_activeEntry!);
    _timer = Timer(duration ?? _defaultDuration, _dismiss);
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
  final Duration? duration,
}) {
  if (!context.mounted) {
    return;
  }

  AppNotificationOverlay.show(context, message, duration: duration);
}

/// Convenience extension so any [BuildContext] can show a notification overlay.
extension AppSnackBarBuildContextX on BuildContext {
  /// Shows a notification overlay message if the context is still mounted.
  void showSnackBarMessage(
    final String message, {
    final Duration? duration,
  }) {
    showSnackBarIfMounted(this, message, duration: duration);
  }
}
