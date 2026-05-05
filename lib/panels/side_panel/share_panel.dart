import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/files/file_heic.dart' if (dart.library.html) 'package:fpaint/files/file_heic_web.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Callback signature for export-format handlers.
typedef _ExportHandler = Future<void> Function(LayersProvider layers);

/// A single export-format row in the share panel.
class _ShareExportEntry {
  const _ShareExportEntry(this.displayFileName, this.onExport);

  /// File-name label shown in the share panel (e.g. 'image.PNG').
  final String displayFileName;

  /// Callback that triggers the export / download.
  final _ExportHandler onExport;
}

/// Display file names shown in the share panel for each export format.
const String _displayPng = 'image.PNG';
const String _displayJpg = 'image.JPG';
const String _displayOra = 'image.ORA';
const String _displayWebp = 'image.WEBP';
const String _displayTif = 'image.TIF';
const String _displayHeic = 'image.HEIC';

/// All export formats available in the share panel.
///
/// HEIC is conditionally included based on platform support.
List<_ShareExportEntry> _exportEntries({
  required final bool includeHeic,
}) => <_ShareExportEntry>[
  const _ShareExportEntry(_displayPng, onExportAsPng),
  const _ShareExportEntry(_displayJpg, onExportAsJpeg),
  const _ShareExportEntry(_displayOra, onExportAsOra),
  const _ShareExportEntry(_displayWebp, onExportAsWebp),
  const _ShareExportEntry(_displayTif, onExportAsTiff),
  if (includeHeic) const _ShareExportEntry(_displayHeic, onExportAsHeic),
];

/// Returns a Text widget with the appropriate action text based on the platform.
///
/// If the app is running on the web, the action text will be "Download as [fileName]".
/// Otherwise, it will be "Save as [fileName]".
Widget textAction(final String fileName, final AppLocalizations l10n) {
  if (kIsWeb) {
    return AppText(l10n.downloadAsFile(fileName));
  }
  return AppText(l10n.saveAsFile(fileName));
}

Future<void> _runSharePanelAction(
  final BuildContext context,
  final Future<void> Function() onAction,
  final bool dismissOnAction,
) async {
  await onAction();
  if (dismissOnAction && context.mounted) {
    Navigator.pop(context);
  }
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
  final BuildContext context, {
  final bool dismissOnAction = true,
}) {
  final LayersProvider layers = LayersProvider.of(context);
  return showAppBottomSheet<void>(
    context: context,
    builder: (final BuildContext context) {
      final AppLocalizations l10n = context.l10n;

      return AppBottomSheetContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
            for (final _ShareExportEntry entry in _exportEntries(
              includeHeic: isHeicExportSupported,
            ))
              AppListTile(
                leading: const AppSvgIcon(icon: AppIcon.iosShare),
                title: textAction(entry.displayFileName, l10n),
                onTap: () async {
                  await _runSharePanelAction(
                    context,
                    () => entry.onExport(layers),
                    dismissOnAction,
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
/// to the clipboard. It uses the `super_clipboard` package to interact with the
/// system clipboard.
///
/// The [context] parameter is the [BuildContext] used to access the LayersProvider
/// and display any error messages.
Future<void> _onExportToClipboard(final BuildContext context) async {
  final SystemClipboard? clipboard = SystemClipboard.instance;
  if (clipboard != null) {
    final Uint8List image = await capturePainterToImageBytes(LayersProvider.of(context));
    final DataWriterItem item = DataWriterItem(suggestedName: 'fPaint.png');
    item.add(Formats.png(image));
    await clipboard.write(<DataWriterItem>[item]);
  } else {
    //
  }
}

/// Captures the current canvas content as an image and returns the image bytes.
///
/// This function uses the `LayersProvider` to capture the current canvas content
/// as an image and returns the image bytes as a `Uint8List`.
///
/// The [layers] parameter is the `LayersProvider` instance used to access the
/// canvas content.
Future<Uint8List> capturePainterToImageBytes(
  final LayersProvider layers,
) async {
  return await layers.capturePainterToImageBytes();
}
