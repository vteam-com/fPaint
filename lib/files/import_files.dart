import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/export_file_name.dart';
import 'package:fpaint/files/file_operation_exception.dart';
import 'package:fpaint/files/flat_image_reader.dart';
import 'package:fpaint/files/import_file_format.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/security_scoped_file_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/providers/undo_provider.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:logging/logging.dart';

const String _defaultCanvasDimension = '800';

final Logger _log = Logger(logNameImportFiles);

/// Shows an import error via the global overlay (so it survives async gaps and
/// does not depend on a possibly-unmounted [BuildContext]), with a copy button
/// so the user can copy the (often exception-bearing) message.
void _showImportError(String message) {
  showGlobalSnackBarMessage(
    message,
    duration: AppDefaults.fileImportFeedbackDuration,
    copyable: true,
  );
}

/// Replaces the current document with the clipboard image and fits it to the
/// view.
///
/// Performs no discard confirmation — use [newDocumentFromClipboardGuarded]
/// unless the caller has already confirmed discarding unsaved work.
/// Completes with `true` when a new document was created.
Future<bool> createDocumentFromClipboard(
  AppProvider appProvider,
  ShellProvider shellProvider,
) async {
  final bool created = await appProvider.newDocumentFromClipboardImage();
  if (created) {
    shellProvider.requestCanvasFit();
  }
  return created;
}

/// The single "New from clipboard" entry point for menus, shortcuts and
/// dialogs.
///
/// Does nothing when the clipboard holds no image. Otherwise asks the user to
/// confirm discarding unsaved changes (if any), then creates the document via
/// [createDocumentFromClipboard] and fits the canvas to the view.
///
/// [appProvider] and [shellProvider] default to the instances found in
/// [context]; pass them explicitly when [context] sits above the editor scope.
/// Completes with `true` when a new document was created.
Future<bool> newDocumentFromClipboardGuarded(
  BuildContext context, {
  AppProvider? appProvider,
  ShellProvider? shellProvider,
}) async {
  final AppProvider app = appProvider ?? AppProvider.of(context);
  final ShellProvider shell = shellProvider ?? ShellProvider.of(context);

  if (!await clipboardHasImage() || !context.mounted) {
    return false;
  }
  if (!await confirmDiscardIfChanged(context, app.layers)) {
    return false;
  }
  return createDocumentFromClipboard(app, shell);
}

/// Handles the creation of a new file within the application.
///
/// This asynchronous function is triggered when the user opts to create a
/// new file. It performs necessary operations to initialize the new file
/// and integrates it into the application's context.
///
/// [context] The BuildContext of the widget that invokes this function.
Future<void> onFileNew(BuildContext context) async {
  final AppProvider appProvider = AppProvider.of(context);
  final ShellProvider shellProvider = ShellProvider.of(context);
  final AppLocalizations l10n = context.l10n;

  if (!await confirmDiscardIfChanged(context, appProvider.layers)) {
    return;
  }

  // Dialog to get desired canvas size
  final bool offNewDocFromClipboard = await clipboardHasImage();

  if (context.mounted) {
    await showAppDialog<Size>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController widthController = TextEditingController(text: _defaultCanvasDimension);
        final TextEditingController heightController = TextEditingController(text: _defaultCanvasDimension);

        return AppDialog(
          title: l10n.newCanvasSize,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.large,
            children: <Widget>[
              AppTextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                hintText: l10n.width,
                selectAllOnFocus: true,
              ),
              AppTextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                hintText: l10n.height,
                selectAllOnFocus: true,
              ),
            ],
          ),
          actions: <Widget>[
            if (offNewDocFromClipboard)
              AppRowSecondaryButton(
                onPressed: () {
                  // Discard was already confirmed at the top of onFileNew.
                  createDocumentFromClipboard(appProvider, shellProvider);
                  Navigator.of(context).pop();
                },
                text: l10n.newFromClipboard,
              ),
            AppRowSecondaryButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              text: l10n.cancel,
            ),
            AppRowPrimaryButton(
              onPressed: () {
                final double? width = double.tryParse(widthController.text);
                final double? height = double.tryParse(heightController.text);
                if (width != null && height != null) {
                  appProvider.canvasClear(Size(width, height));
                  shellProvider.requestCanvasFit();
                  Navigator.of(context).pop();
                } else {
                  // Show error message if input is invalid
                  context.showSnackBarMessage(l10n.invalidSize);
                }
              },
              text: l10n.create,
            ),
          ],
        );
      },
    );
  }
}

/// Opens a file and performs necessary operations.
///
/// This function is triggered when a file is opened in the application.
/// It performs asynchronous operations to handle the file appropriately.
///
/// Parameters:
/// - `context`: The `BuildContext` of the current widget tree.
///
/// Returns:
/// - A `Future<void>` indicating the completion of the file open operation.
Future<void> onFileOpen(BuildContext context) async {
  final ShellProvider shellProvider = ShellProvider.of(context);
  final LayersProvider layers = LayersProvider.of(context);
  final AppLocalizations l10n = context.l10n;
  // Resolve the preferences provider before any await so recent-file tracking
  // never reaches back into a possibly-defunct BuildContext.
  final AppPreferences preferences = AppPreferences.of(context);

  if (!await confirmDiscardIfChanged(context, layers)) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  if (SecurityScopedFileService.supportsInPlaceDocuments) {
    await _openInPlaceDocument(
      context: context,
      shellProvider: shellProvider,
      layers: layers,
      preferences: preferences,
    );
    return;
  }

  try {
    final PlatformFile? result = await FilePicker.pickFile(
      dialogTitle: l10n.fpaintLoadImage,
      // type: FileType.custom,
      // allowedExtensions: supportedImageFileExtensions,
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );

    if (result != null) {
      // layers.clear(); // Removed from here

      if (kIsWeb) {
        final Uint8List bytes = await result.readAsBytes();
        final String fileName = result.name; // Get filename for naming the layer
        final String extension = fileExtensionOf(fileName);
        final ImportFileFormat? format = ImportFileFormat.fromExtension(extension);
        if (format != null) {
          await _readDocument(
            layers: layers,
            bytes: bytes,
            format: format,
            fileName: fileName,
            l10n: l10n,
          );
        }
        layers.clearHasChanged();
        shellProvider.requestCanvasFit();
      } else {
        final String path = result.path!;
        shellProvider.loadedFileName = path;
        if (context.mounted) {
          await openFileFromPath(
            context: context,
            layers: layers,
            path: path,
            preferences: preferences,
          );
        }
        await finishDocumentOpen(
          shellProvider: shellProvider,
          layers: layers,
          preferences: preferences,
          path: path,
        );
      }
    }
  } catch (e) {
    // Handle any errors that occur during file picking/loading
    _log.severe('Error opening file', e);
  }
}

/// Picks a document in place (iOS) and opens it.
///
/// The `file_picker` plugin imports a private copy of the picked file, so
/// saving would never reach the original in iCloud Drive, Synology Drive or
/// any other File Provider. Opening in place keeps the original path, and its
/// bookmark lets Save write back to it.
Future<void> _openInPlaceDocument({
  required BuildContext context,
  required ShellProvider shellProvider,
  required LayersProvider layers,
  required AppPreferences preferences,
}) async {
  try {
    final InPlaceDocument? document = await SecurityScopedFileService.pickDocumentInPlace();
    if (document == null || !context.mounted) {
      return;
    }
    shellProvider.loadedFileName = document.path;
    await SecurityScopedFileService.withResolvedBookmark<bool>(
      bookmarkBase64: document.bookmark,
      fallbackPath: document.path,
      action: (String resolvedPath) => openFileFromPath(
        context: context,
        layers: layers,
        path: resolvedPath,
        preferences: preferences,
      ),
    );
    await finishDocumentOpen(
      shellProvider: shellProvider,
      layers: layers,
      preferences: preferences,
      path: document.path,
      bookmark: document.bookmark,
    );
  } catch (e) {
    _log.severe('Error opening file in place', e);
  }
}

/// Completes opening the document at [path]: records it as the loaded file,
/// marks the canvas clean, fits it to the view and adds it to the recent files
/// (keeping [bookmark] when the document was opened through one).
///
/// The shared tail of every open flow (picker, in-place, drop, recent files).
Future<void> finishDocumentOpen({
  required ShellProvider shellProvider,
  required LayersProvider layers,
  required AppPreferences preferences,
  required String path,
  String? bookmark,
}) async {
  shellProvider.loadedFileName = path;
  layers.clearHasChanged();
  shellProvider.requestCanvasFit();
  await preferences.addRecentFile(path, bookmark: bookmark);
}

/// Opens a file from the specified file path.
///
/// This function takes a file path as input and performs the necessary
/// operations to open the file. It provides feedback when unsupported file types
/// are encountered.
///
/// Parameters:
/// - `layers`: The LayersProvider to load the file into
/// - `path`: A string representing the path to the file to be opened.
///
/// Returns:
/// - A `Future<bool>` that completes with true if the file was successfully opened,
///   or false if the file type is not supported.
Future<bool> openFileFromPath({
  required BuildContext context,
  required LayersProvider layers,
  required String path,
  AppPreferences? preferences,
}) async {
  if (!context.mounted) {
    return false;
  }

  // Capture localization up front so the rest of the flow never touches the
  // BuildContext across the await points below.
  final AppLocalizations l10n = context.l10n;
  final String extension = fileExtensionOf(path);

  final ImportFileFormat? format = ImportFileFormat.fromExtension(extension);
  if (format == null) {
    // Show unsupported format message
    _showImportError(l10n.fileFormatNotSupported(extension));
    return false;
  }

  final Uint8List? bytes = await _readFileBytes(path, l10n);
  if (bytes == null) {
    return false;
  }
  final bool loaded = await _readDocument(
    layers: layers,
    bytes: bytes,
    format: format,
    fileName: fileNameOf(path),
    l10n: l10n,
  );
  // Layered formats embed (or lack) their own selection; flat formats fall
  // back to the per-path preference.
  if (!format.supportsLayers) {
    _restoreFlatLayerSelection(preferences, layers, path, loaded: loaded);
  }
  return loaded;
}

/// Reads [path]'s bytes, reporting a read failure and returning null.
Future<Uint8List?> _readFileBytes(String path, AppLocalizations l10n) async {
  try {
    return await File(path).readAsBytes();
  } catch (e) {
    _showImportError(l10n.errorReadingFile(e.toString()));
    return null;
  }
}

/// Decodes [bytes] as [format] into [layers] (replacing the document) and
/// reports any failure to the user. Completes with whether it loaded.
Future<bool> _readDocument({
  required LayersProvider layers,
  required Uint8List bytes,
  required ImportFileFormat format,
  required String fileName,
  required AppLocalizations l10n,
}) async {
  try {
    await format.read(layers, bytes, fileName);
    return true;
  } catch (e) {
    _showImportError(_importErrorMessage(l10n, format, fileName, e));
    return false;
  }
}

/// The user-facing message for a failed decode of [fileName] as [format].
String _importErrorMessage(
  AppLocalizations l10n,
  ImportFileFormat format,
  String fileName,
  Object error,
) {
  if (error is HeicConversionException) {
    return l10n.fileFormatNotSupportedOnPlatform(fileExtensionOf(fileName));
  }
  return format.supportsLayers ? l10n.errorProcessingFile(error.toString()) : l10n.failedToLoadImage(error.toString());
}

/// Restores the remembered selection for a flat (non-layered) file.
///
/// Flat formats cannot embed the selected layer, so it is looked up from
/// [preferences] by path. The index is applied only when it is still within the
/// current layer range (flat files typically reload as a single base layer).
/// No-op when the load failed or no preference is available.
void _restoreFlatLayerSelection(
  AppPreferences? preferences,
  LayersProvider layers,
  String path, {
  required bool loaded,
}) {
  if (!loaded || preferences == null) {
    return;
  }
  final int? index = preferences.lastSelectedLayerFor(path);
  if (index != null && layers.isIndexInRange(index)) {
    layers.selectedLayerIndex = index;
  }
}

/// Every file extension the app can open.
final List<String> supportedImageFileExtensions = ImportFileFormat.allExtensions;

/// Checks if the given file extension is supported.
///
/// This function takes a file extension as input and determines whether
/// it is supported by the application.
///
/// [extension] The file extension to check (e.g., "jpg", "png").
///
/// Returns `true` if the file extension is supported, otherwise `false`.
bool isFileExtensionSupported(String extension) {
  return supportedImageFileExtensions.contains(extension.toLowerCase());
}

/// The result chosen by the user when dropping a file onto a canvas that
/// already contains content.
enum DropFileAction {
  /// Open the file, replacing the current content.
  open,

  /// Add the file as a new layer on top of the existing content.
  addLayer,
}

/// Handles a file dropped onto the canvas from the desktop.
///
/// When the canvas has no meaningful content the file is opened directly.
/// Otherwise a dialog asks the user whether to open the file (replacing the
/// current content) or to add it as a new layer.
Future<void> onFileDropped({
  required BuildContext context,
  required String path,
}) async {
  final LayersProvider layers = LayersProvider.of(context);
  final ShellProvider shellProvider = ShellProvider.of(context);
  final AppPreferences preferences = AppPreferences.of(context);

  final String extension = fileExtensionOf(path);
  if (!isFileExtensionSupported(extension)) {
    _showImportError(context.l10n.fileFormatNotSupported(extension));
    return;
  }

  final bool canvasHasContent = layers.list.any(
    (LayerProvider layer) => layer.actionStack.isNotEmpty,
  );

  if (canvasHasContent) {
    final DropFileAction? action = await showAppDialog<DropFileAction>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = dialogContext.l10n;
        return AppDialog(
          title: l10n.dropFileTitle,
          content: AppText(l10n.dropFilePrompt),
          actions: <Widget>[
            AppRowSecondaryButton(
              onPressed: () => Navigator.pop(dialogContext, DropFileAction.addLayer),
              text: l10n.dropFileAddLayer,
            ),
            AppRowPrimaryButton(
              onPressed: () => Navigator.pop(dialogContext, DropFileAction.open),
              text: l10n.dropFileOpen,
            ),
          ],
        );
      },
    );

    if (action == null || !context.mounted) {
      return;
    }

    if (action == DropFileAction.addLayer) {
      await addFileAsLayer(
        context: context,
        layers: layers,
        path: path,
      );
      return;
    }
  }

  // Open the file, replacing the current content.
  if (context.mounted) {
    await openFileFromPath(context: context, layers: layers, path: path, preferences: preferences);
    await finishDocumentOpen(
      shellProvider: shellProvider,
      layers: layers,
      preferences: preferences,
      path: path,
    );
  }
}

/// Decodes the file at [path] in any openable format and adds it, flattened,
/// as a new layer on top of the current layer stack.
///
/// Layered formats (ORA, PSD, TIFF) are decoded into a scratch document and
/// composited with their own blend modes and opacities, so the added layer
/// looks exactly like the file would when opened.
Future<void> addFileAsLayer({
  required BuildContext context,
  required LayersProvider layers,
  required String path,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String fileName = fileNameOf(path);
  final ImportFileFormat? format = ImportFileFormat.fromFileName(fileName);
  if (format == null) {
    _showImportError(l10n.fileFormatNotSupported(fileExtensionOf(fileName)));
    return;
  }
  final Uint8List? bytes = await _readFileBytes(path, l10n);
  if (bytes == null) {
    return;
  }

  final LayersProvider scratch = LayersProvider(undoProvider: UndoProvider());
  try {
    if (await _readDocument(layers: scratch, bytes: bytes, format: format, fileName: fileName, l10n: l10n)) {
      final ui.Image flattened = await scratch.capturePainterToImage();
      // Hand the composite over to [layers]; the scratch document must not
      // dispose it.
      scratch.cachedImage = null;
      addImageAsTopLayer(layers, flattened, fileName);
      layers.update();
    }
  } finally {
    scratch.dispose();
  }
}
