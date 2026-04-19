import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/export_download_non_web.dart'
    if (dart.library.html) 'package:fpaint/files/export_download_web.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_svg_icon.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Returns a Text widget with the appropriate action text based on the platform.
///
/// If the app is running on the web, the action text will be "Download as [fileName]".
/// Otherwise, it will be "Save as [fileName]".
Widget textAction(final String fileName, final AppLocalizations l10n) {
  if (kIsWeb) {
    return Text(l10n.downloadAsFile(fileName));
  }
  return Text(l10n.saveAsFile(fileName));
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
void sharePanel(final BuildContext context) {
  final LayersProvider layers = LayersProvider.of(context);
  showModalBottomSheet<dynamic>(
    context: context,
    builder: (final BuildContext context) {
      final AppLocalizations l10n = context.l10n;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl + AppSpacing.thin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.copy),
                title: Text(l10n.copyToClipboard),
                onTap: () {
                  Navigator.pop(context);
                  _onExportToClipboard(context);
                },
              ),
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.download),
                title: textAction('image.PNG', l10n),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsPng(layers);
                },
              ),
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.download),
                title: textAction('image.JPG', l10n),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsJpeg(layers);
                },
              ),
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.download),
                title: textAction('image.ORA', l10n),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsOra(layers);
                },
              ),
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.download),
                title: textAction('image.WEBP', l10n),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsWebp(layers);
                },
              ),
              ListTile(
                leading: const AppSvgIcon(icon: AppIcon.download),
                title: textAction('image.TIF', l10n),
                onTap: () {
                  Navigator.pop(context);
                  onExportAsTiff(layers);
                },
              ),
            ],
          ),
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
