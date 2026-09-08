import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/files/save.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Export formats offered in the share panel, in display order.
///
/// Driven by [SaveFileFormat] so a new format appears here as soon as it is
/// added to the enum; only the order is stated locally (Open/Closed).
const List<SaveFileFormat> _shareExportOrder = <SaveFileFormat>[
  SaveFileFormat.png,
  SaveFileFormat.jpeg,
  SaveFileFormat.ora,
  SaveFileFormat.webp,
  SaveFileFormat.tiff,
  SaveFileFormat.heic,
];

/// The formats to show, dropping HEIC where the platform cannot encode it.
List<SaveFileFormat> _exportFormats({required bool includeHeic}) => <SaveFileFormat>[
  for (final SaveFileFormat format in _shareExportOrder)
    if (includeHeic || format != SaveFileFormat.heic) format,
];

/// File-name label shown in the share panel for [format], e.g. `image.PNG`.
String _displayFileName(SaveFileFormat format) => '$exportBaseFileName.${format.displayName}';

/// Returns a Text widget with the appropriate action text based on the platform.
///
/// If the app is running on the web, the action text will be "Download as [fileName]".
/// Otherwise, it will be "Save as [fileName]".
Widget textAction(String fileName, AppLocalizations l10n) {
  if (kIsWeb) {
    return AppText(l10n.downloadAsFile(fileName));
  }
  return AppText(l10n.saveAsFile(fileName));
}

Future<void> _runSharePanelAction(
  BuildContext context,
  Future<void> Function() onAction,
  bool dismissOnAction,
) async {
  await onAction();
  if (dismissOnAction && context.mounted) {
    Navigator.pop(context);
  }
}

/// Runs a share-panel export while showing global export progress feedback.
Future<void> _runSharePanelExportAction({
  required BuildContext context,
  required Future<void> Function() onAction,
  required String displayFileName,
  required bool dismissOnAction,
}) async {
  final AppLocalizations l10n = context.l10n;

  await _runSharePanelAction(
    context,
    () {
      return runWithGlobalProgressSnackBar<void>(
        showInProgress: () {
          showGlobalProgressSnackBarMessage(
            l10n.exportingLabel,
            subtitle: displayFileName,
          );
        },
        showOnSuccess: () {
          showGlobalSnackBarMessage(
            l10n.exportedLabel,
            subtitle: displayFileName,
          );
        },
        task: onAction,
      );
    },
    dismissOnAction,
  );
}

/// Displays a modal bottom sheet with options to share the canvas.
///
/// This function presents a list of options to the user, including:
/// - Copy to clipboard
/// - Download as PNG
/// - Download as JPG
/// - Download as ORA
///
/// The [context] parameter is the [BuildContext] used to display the modal.
Future<void> sharePanel(
  BuildContext context, {
  bool dismissOnAction = true,
}) {
  final LayersProvider layers = LayersProvider.of(context);
  return showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l10n = context.l10n;
      final AppPreferences preferences = AppPreferences.of(context);
      final String loadedFilePath = ShellProvider.of(context).loadedFileName.trim();

      return AppBottomSheetContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loadedFilePath.isNotEmpty) ...<Widget>[
              AppListTile(
                leading: const AppSvgIcon(icon: AppIcon.image),
                title: Text(
                  loadedFilePath,
                  maxLines: AppMath.pair,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subtitle.copyWith(color: AppColors.white),
                ),
              ),
              const AppDivider(),
            ],
            AppListTile(
              leading: const AppSvgIcon(icon: AppIcon.clipboardCopy),
              title: AppText(l10n.copyToClipboard),
              onTap: () async {
                await _runSharePanelAction(
                  context,
                  () => _onExportToClipboard(context),
                  dismissOnAction,
                );
              },
            ),
            for (final SaveFileFormat format in _exportFormats(includeHeic: isHeicExportSupported))
              AppListTile(
                leading: const AppSvgIcon(icon: AppIcon.iosShare),
                title: textAction(_displayFileName(format), l10n),
                onTap: () async {
                  await _runSharePanelExportAction(
                    context: context,
                    onAction: () => exportAs(format, layers, preferences: preferences),
                    displayFileName: _displayFileName(format),
                    dismissOnAction: dismissOnAction,
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Exports the current canvas content to the clipboard as a PNG image.
///
/// This function captures the current canvas content as a PNG image and copies it
/// to the system clipboard.
///
/// The [context] parameter is the [BuildContext] used to access the LayersProvider
/// and display any error messages.
Future<void> _onExportToClipboard(BuildContext context) async {
  final Uint8List image = await capturePainterToImageBytes(LayersProvider.of(context));
  await copyImageBytesToClipboard(image);
}

/// Captures the current canvas content as an image and returns the image bytes.
///
/// This function uses the `LayersProvider` to capture the current canvas content
/// as an image and returns the image bytes as a `Uint8List`.
///
/// The [layers] parameter is the `LayersProvider` instance used to access the
/// canvas content.
Future<Uint8List> capturePainterToImageBytes(
  LayersProvider layers,
) async {
  return await layers.capturePainterToImageBytes();
}
