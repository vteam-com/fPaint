import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/macos_bookmark_service.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/app_provider_canvas.dart';
import 'package:fpaint/providers/app_provider_selection.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';

const String _oraFileSuffix = '.${FileExtensions.ora}';

/// Returns thumbnail-ready bytes for MRU previews, including ORA archives.
Future<Uint8List?> resolveRecentFileThumbnailBytes({
  required final Uint8List fileBytes,
  required final String path,
}) async {
  if (!_isOraPath(path)) {
    return fileBytes;
  }

  return extractOraPreviewPngBytes(fileBytes);
}

bool _isOraPath(final String path) {
  return path.toLowerCase().endsWith(_oraFileSuffix);
}

/// The unified import dialog widget.
class ImportDialog extends StatefulWidget {
  const ImportDialog({
    super.key,
    required this.parentContext,
    this.clipboardImageLoader,
  });

  final Future<ui.Image?> Function()? clipboardImageLoader;

  /// The context from which the dialog was opened, used for provider access
  /// after the dialog closes.
  final BuildContext parentContext;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _addAsLayer = false;
  ui.Image? _clipboardPreview;
  @override
  void initState() {
    super.initState();
    _loadClipboardPreview();
  }

  @override
  Widget build(final BuildContext context) {
    final AppPreferences prefs = AppPreferences.of(widget.parentContext);
    final AppLocalizations l10n = context.l10n;
    final List<String> recentFiles = prefs.recentFiles.take(AppLimits.recentFilesDisplayCount).toList();

    return AppBottomSheetContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppText(
            l10n.importLabel,
            variant: AppTextVariant.title,
          ),
          const SizedBox(height: AppSpacing.large),
          AppSwitchListTile(
            title: AppText(l10n.addAsNewLayer),
            value: _addAsLayer,
            onChanged: (final bool value) {
              setState(() {
                _addAsLayer = value;
              });
            },
          ),
          if (_clipboardPreview != null) ...<Widget>[
            const SizedBox(height: AppSpacing.big),
            _buildClipboardTile(l10n),
          ],
          if (!kIsWeb && recentFiles.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.large),
            _buildSectionHeader(l10n.recentFilesLabel),
            const SizedBox(height: AppSpacing.small),
            for (final String path in recentFiles)
              _RecentFileEntry(
                key: ValueKey<String>(path),
                path: path,
                bookmark: prefs.getBookmark(path),
                onTap: () {
                  final String? bookmark = prefs.getBookmark(path);
                  Navigator.pop(context);
                  if (_addAsLayer) {
                    _addRecentAsLayer(widget.parentContext, path, bookmark);
                  } else {
                    _openRecentFile(widget.parentContext, path, bookmark);
                  }
                },
                onDiscard: () async {
                  try {
                    await AppPreferences.of(widget.parentContext).removeRecentFile(path);
                    if (mounted) {
                      setState(() {});
                    }
                  } catch (e) {
                    // Silently fail if unable to remove the file
                    debugPrint('Failed to remove recent file: $e');
                  }
                },
              ),
          ],
          const SizedBox(height: AppSpacing.large),
          AppButtonRow(
            actions: <Widget>[
              AppRowSecondaryButton(
                onPressed: () => Navigator.pop(context),
                text: l10n.cancel,
              ),
              AppRowPrimaryButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_addAsLayer) {
                    _browseAndAddAsLayer(widget.parentContext);
                  } else {
                    onFileOpen(widget.parentContext);
                  }
                },
                text: l10n.browseFiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the preview graphic shown inside the clipboard import tile.
  Widget _buildClipboardPreviewGraphic() {
    if (_clipboardPreview != null) {
      return RawImage(
        image: _clipboardPreview,
        fit: BoxFit.cover,
      );
    }

    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: AppSvgIcon(
          icon: AppIcon.clipboardPaste,
          size: AppLayout.recentFileMissingIconSize,
        ),
      ),
    );
  }

  /// Builds the clickable clipboard source tile shown when an image is available.
  Widget _buildClipboardTile(final AppLocalizations l10n) {
    return GestureDetector(
      onTap: _handleClipboardImport,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _buildImportTileSurface(
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: SizedBox(
                  width: AppLayout.thumbnailMaxHeight,
                  height: AppLayout.thumbnailMaxHeight,
                  child: _buildClipboardPreviewGraphic(),
                ),
              ),
              const SizedBox(width: AppSpacing.large),
              Expanded(
                child: AppText(
                  l10n.fromClipboard,
                  variant: AppTextVariant.bodyBold,
                ),
              ),
              const AppSvgIcon(
                icon: AppIcon.clipboardPaste,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(final String label) {
    return Row(
      children: <Widget>[
        AppText(label, variant: AppTextVariant.subtitle),
        const SizedBox(width: AppSpacing.medium),
        const Expanded(child: AppDivider()),
      ],
    );
  }

  void _handleClipboardImport() {
    Navigator.pop(context);
    final AppProvider appProvider = AppProvider.of(widget.parentContext);
    if (_addAsLayer) {
      appProvider.paste();
      return;
    }
    appProvider.newDocumentFromClipboardImage();
  }

  /// Loads the current clipboard image once so the dialog can render a preview.
  Future<void> _loadClipboardPreview() async {
    final Future<ui.Image?> Function() clipboardImageLoader = widget.clipboardImageLoader ?? getImageFromClipboard;
    final ui.Image? clipboardImage = await clipboardImageLoader();
    if (!mounted) {
      return;
    }
    setState(() {
      _clipboardPreview = clipboardImage;
    });
  }
}

/// Shared surface styling for the import dialog source tiles and recent rows.
Widget _buildImportTileSurface({required final Widget child}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      border: Border.all(
        color: AppColors.overlayBorder,
        width: AppStroke.thin,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: child,
    ),
  );
}

/// Opens the file picker and adds the selected file as a new layer.
Future<void> _browseAndAddAsLayer(final BuildContext context) async {
  final LayersProvider layers = LayersProvider.of(context);

  try {
    final FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: context.l10n.fpaintLoadImage,
      allowMultiple: false,
      withData: true,
      lockParentWindow: true,
    );

    if (result != null && !kIsWeb) {
      final String path = result.files.single.path!;
      if (context.mounted) {
        await addFileAsLayer(context: context, layers: layers, path: path);
        if (context.mounted) {
          await AppPreferences.of(context).addRecentFile(path);
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      context.showSnackBarMessage(
        context.l10n.failedToLoadImage(e.toString()),
      );
    }
  }
}

/// Opens a recent file by path, handling unsaved changes and file existence.
Future<void> _openRecentFile(
  final BuildContext context,
  final String path,
  final String? bookmark,
) async {
  final LayersProvider layers = LayersProvider.of(context);
  final ShellProvider shellProvider = ShellProvider.of(context);

  if (layers.hasChanged && await confirmDiscardCurrentWork(context) == false) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final bool success = await MacOsBookmarkService.withResolvedBookmark(
    bookmarkBase64: bookmark,
    fallbackPath: path,
    action: (final String resolvedPath) => openFileFromPath(
      context: context,
      layers: layers,
      path: resolvedPath,
    ),
  );

  if (success) {
    shellProvider.loadedFileName = path;
    layers.clearHasChanged();
    shellProvider.requestCanvasFit();
    if (context.mounted) {
      await AppPreferences.of(context).addRecentFile(path);
    }
  } else if (context.mounted) {
    context.showSnackBarMessage(context.l10n.errorReadingFile(path));
  }
}

/// Adds a recent file as a new layer, checking that the file exists.
Future<void> _addRecentAsLayer(
  final BuildContext context,
  final String path,
  final String? bookmark,
) async {
  final LayersProvider layers = LayersProvider.of(context);

  if (!context.mounted) {
    return;
  }

  await MacOsBookmarkService.withResolvedBookmark(
    bookmarkBase64: bookmark,
    fallbackPath: path,
    action: (final String resolvedPath) => addFileAsLayer(context: context, layers: layers, path: resolvedPath),
  );
  if (context.mounted) {
    await AppPreferences.of(context).addRecentFile(path);
  }
}

/// A recent file entry with an async-loaded thumbnail preview.
class _RecentFileEntry extends StatefulWidget {
  const _RecentFileEntry({
    super.key,
    required this.path,
    required this.bookmark,
    required this.onTap,
    required this.onDiscard,
  });
  final String? bookmark;
  final Future<void> Function() onDiscard;
  final VoidCallback onTap;
  final String path;
  @override
  State<_RecentFileEntry> createState() => _RecentFileEntryState();
}

class _RecentFileEntryState extends State<_RecentFileEntry> {
  bool _fileExists = true;
  bool _loadFailed = false;
  ui.Image? _thumbnail;
  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  Widget build(final BuildContext context) {
    final String fileName = widget.path.split(Platform.pathSeparator).last;
    final AppLocalizations l10n = context.l10n;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
          child: _buildImportTileSurface(
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: SizedBox(
                    width: AppLayout.thumbnailMaxHeight,
                    height: AppLayout.thumbnailMaxHeight,
                    child: _buildThumbnail(),
                  ),
                ),
                const SizedBox(width: AppSpacing.large),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppText(fileName),
                    ],
                  ),
                ),
                AppButtonIcon(
                  tooltip: l10n.delete,
                  icon: AppIcon.playlistRemove,
                  onPressed: () {
                    widget.onDiscard();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the thumbnail image, a placeholder on failure, or a progress
  /// indicator while loading.
  Widget _buildThumbnail() {
    if (_thumbnail != null) {
      return RawImage(
        image: _thumbnail,
        fit: BoxFit.contain,
      );
    }
    if (_loadFailed) {
      final AppLocalizations l10n = context.l10n;
      final String label = _fileExists ? l10n.previewUnavailable : l10n.fileNotFound;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider, width: AppStroke.thin),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const AppSvgIcon(
                icon: AppIcon.image,
                size: AppLayout.recentFileMissingIconSize,
              ),
              const SizedBox(height: AppSpacing.small),
              AppText(
                label,
                variant: AppTextVariant.subtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return const AppProgressIndicator();
  }

  /// Asynchronously decodes the image file and scales it to a thumbnail.
  Future<void> _loadThumbnail() async {
    try {
      await MacOsBookmarkService.withResolvedBookmark(
        bookmarkBase64: widget.bookmark,
        fallbackPath: widget.path,
        action: (final String resolvedPath) async {
          final File file = File(resolvedPath);
          if (!file.existsSync()) {
            if (mounted) {
              setState(() {
                _fileExists = false;
                _loadFailed = true;
              });
            }
            return;
          }
          final Uint8List bytes = await file.readAsBytes();
          final Uint8List? thumbnailBytes = await resolveRecentFileThumbnailBytes(
            fileBytes: bytes,
            path: resolvedPath,
          );
          if (thumbnailBytes == null) {
            if (mounted) {
              setState(() {
                _loadFailed = true;
              });
            }
            return;
          }
          final ui.Codec codec = await ui.instantiateImageCodec(
            thumbnailBytes,
            targetHeight: AppLayout.thumbnailMaxHeight.toInt(),
          );
          final ui.FrameInfo frame = await codec.getNextFrame();
          if (mounted) {
            setState(() {
              _thumbnail = frame.image;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
        });
      }
    }
  }
}
