import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/macos_bookmark_service.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';

/// The unified import dialog widget.
class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key, required this.parentContext});

  /// The context from which the dialog was opened, used for provider access
  /// after the dialog closes.
  final BuildContext parentContext;

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _addAsLayer = false;

  @override
  Widget build(final BuildContext context) {
    final AppPreferences prefs = AppPreferences.of(widget.parentContext);
    final AppLocalizations l10n = context.l10n;
    final List<String> recentFiles = prefs.recentFiles.take(AppLimits.recentFilesDisplayCount).toList();

    return AppDialog(
      title: l10n.importLabel,
      content: SizedBox(
        width: AppLayout.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSwitchListTile(
              title: AppText(l10n.addAsNewLayer),
              value: _addAsLayer,
              onChanged: (final bool value) {
                setState(() {
                  _addAsLayer = value;
                });
              },
            ),
            const SizedBox(height: AppSpacing.big),
            AppButtonPrimary(
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
            if (!kIsWeb && recentFiles.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.large),
              AppText(l10n.recentFilesLabel, variant: AppTextVariant.subtitle),
              const SizedBox(height: AppSpacing.small),
              for (final String path in recentFiles)
                _RecentFileEntry(
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
          ],
        ),
      ),
      actions: <Widget>[
        AppButtonText(
          onPressed: () => Navigator.pop(context),
          text: l10n.cancel,
        ),
      ],
    );
  }
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
          child: Row(
            children: <Widget>[
              SizedBox(
                width: AppLayout.thumbnailMaxHeight,
                height: AppLayout.thumbnailMaxHeight,
                child: _buildThumbnail(),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppText(fileName),
                    AppText(
                      widget.path,
                      variant: AppTextVariant.subtitle,
                    ),
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
          border: Border.all(color: AppColors.divider, width: 1),
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
          final ui.Codec codec = await ui.instantiateImageCodec(
            bytes,
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
