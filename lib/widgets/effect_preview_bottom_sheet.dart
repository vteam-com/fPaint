import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/selection_effect.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/widgets/effect_intensity_controls.dart';
import 'package:fpaint/widgets/material_free.dart';

const int _effectPreviewBottomSheetWaitFrameCount = 120;
const Duration _effectPreviewBottomSheetWaitFrameDuration = Duration(milliseconds: 16);

/// Shows effect intensity controls for a live effect preview.
void showEffectPreviewBottomSheet(
  final BuildContext context, {
  required final AppProvider appProvider,
  required final AppLocalizations l10n,
}) {
  showAppBottomSheet<void>(
    context: context,
    barrierColor: AppColors.transparent,
    builder: (final BuildContext sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.modalSheetContentMaxWidth,
          ),
          child: EffectIntensityControls(
            appProvider: appProvider,
            l10n: l10n,
            sliderKey: Keys.effectIntensityDialogSlider,
            applyButtonKey: Keys.effectIntensityApplyButton,
            cancelButtonKey: Keys.effectIntensityCancelButton,
            onDismiss: () => Navigator.of(sheetCtx).pop(),
          ),
        ),
      ),
    ),
  );
}

/// Starts a selection-effect preview and opens the controls as soon as preview
/// mode becomes visible, without waiting for the preview render to finish.
Future<void> startEffectPreviewWithBottomSheet(
  final BuildContext context, {
  required final AppProvider appProvider,
  required final AppLocalizations l10n,
  required final SelectionEffect effect,
}) async {
  final Future<void> previewFuture = appProvider.startEffectPreview(effect);

  for (int i = 0; i < _effectPreviewBottomSheetWaitFrameCount; i++) {
    if (!context.mounted) {
      return;
    }

    if (appProvider.effectPreviewModel.isVisible && appProvider.effectPreviewModel.effect == effect) {
      showEffectPreviewBottomSheet(
        context,
        appProvider: appProvider,
        l10n: l10n,
      );
      break;
    }

    await Future<void>.delayed(_effectPreviewBottomSheetWaitFrameDuration);
  }

  await previewFuture;
}
