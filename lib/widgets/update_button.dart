import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/inherited_provider.dart';
import 'package:fpaint/updates/app_release.dart';
import 'package:fpaint/updates/app_update_controller.dart';
import 'package:fpaint/updates/app_update_exception.dart';
import 'package:fpaint/widgets/app_snackbar.dart';
import 'package:fpaint/widgets/toolbar_icon_button.dart';

/// Asks whether the app may quit to install an update.
typedef UpdateQuitConfirmation = Future<bool> Function(BuildContext context);

/// The top-bar button installing a newer fPaint release, shown only while
/// [AppUpdateController.available] has one. Tapping it confirms unsaved work
/// via [confirmQuit], downloads the release, and restarts into it; a failure
/// shows a localized message and leaves the app running.
class UpdateButton extends StatelessWidget {
  /// Creates an [UpdateButton].
  const UpdateButton({
    super.key,
    required this.interactionProfile,
    required this.confirmQuit,
  });

  /// Asks whether unsaved work may be left behind.
  final UpdateQuitConfirmation confirmQuit;

  /// Sizes the button like its toolbar neighbours.
  final InteractionLayoutProfile interactionProfile;

  @override
  Widget build(BuildContext context) {
    final AppUpdateController? controller = InheritedControllerScope.maybeOf<AppUpdateController>(context);
    final AppRelease? release = controller?.available;
    if (controller == null || release == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = context.l10n;
    return buildToolbarIconButton(
      key: Keys.toolbarUpdateButton,
      tooltip: l10n.updateAvailableTooltip(release.version.toString()),
      icon: AppIcon.download,
      color: AppColors.selected,
      enabled: !controller.installing,
      interactionProfile: interactionProfile,
      onPressed: () => _install(context, controller),
    );
  }

  /// Installs the release through [controller], showing a localized message
  /// when staging fails.
  Future<void> _install(BuildContext context, AppUpdateController controller) async {
    final AppLocalizations l10n = context.l10n;
    try {
      await controller.install(confirmQuit: () => confirmQuit(context));
    } on AppUpdateException catch (error) {
      if (context.mounted) {
        showSnackBarIfMounted(
          context,
          l10n.updateFailed,
          subtitle: updateFailureMessage(l10n, error),
          copyable: true,
        );
      }
    }
  }
}

/// The localized explanation of [error].
String updateFailureMessage(AppLocalizations l10n, AppUpdateException error) {
  return switch (error.failure) {
    AppUpdateFailure.network => l10n.updateFailedNetwork,
    AppUpdateFailure.notWritable => l10n.updateFailedNotWritable(error.detail),
    AppUpdateFailure.invalidBuild => l10n.updateFailedInvalidBuild,
    AppUpdateFailure.unpack => l10n.updateFailedUnpack,
  };
}
