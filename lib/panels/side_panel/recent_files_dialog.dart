import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter_material show MaterialLocalizations, TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/files/file_psd.dart';
import 'package:fpaint/files/import_files.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/helpers/log_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/providers/app_preferences.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/providers/security_scoped_file_service.dart';
import 'package:fpaint/providers/shell_provider.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/confirm_discard_dialog.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger(logNameRecentFiles);

const String _oraFileSuffix = '.${FileExtensions.ora}';
const String _psdFileSuffix = '.${FileExtensions.psd}';
const String _logMetadataFailed = 'Failed to read recent file metadata';
const String _logThumbnailFailed = 'Failed to load recent file thumbnail';

typedef RecentFileMetadata = ({bool exists, DateTime? lastModified});
typedef RecentFileMetadataLoader = Future<RecentFileMetadata> Function(String path, String? bookmark);

/// Loads the MRU thumbnail of the file at `path` (resolved via `bookmark`).
typedef RecentFileThumbnailLoader = Future<ui.Image?> Function(String path, String? bookmark);

/// Returns thumbnail-ready bytes for MRU previews.
///
/// ORA and PSD are containers the image decoder cannot read directly, so their
/// embedded composite preview is extracted first. Every other format is already
/// decodable as-is.
Future<Uint8List?> resolveRecentFileThumbnailBytes({
  required Uint8List fileBytes,
  required String path,
}) async {
  final String normalized = path.toLowerCase();

  if (normalized.endsWith(_oraFileSuffix)) {
    return extractOraPreviewPngBytes(fileBytes);
  }
  if (normalized.endsWith(_psdFileSuffix)) {
    return extractPsdPreviewPngBytes(fileBytes);
  }

  return fileBytes;
}

/// Opens the unified [ImportDialog] as a bottom sheet anchored to [context].
///
/// Shared by the top toolbar and the main menu so both open the same sheet.
Future<void> showImportSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext _) => ImportDialog(parentContext: context),
  );
}

/// The unified import dialog widget.
class ImportDialog extends StatefulWidget {
  const ImportDialog({
    super.key,
    required this.parentContext,
    this.clipboardImageLoader,
    this.recentFileMetadataLoader,
    this.recentFileThumbnailLoader,
  });
  final Future<ui.Image?> Function()? clipboardImageLoader;

  /// The context from which the dialog was opened, used for provider access
  /// after the dialog closes.
  final BuildContext parentContext;
  final RecentFileMetadataLoader? recentFileMetadataLoader;
  final RecentFileThumbnailLoader? recentFileThumbnailLoader;
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
  Widget build(BuildContext context) {
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
            onChanged: (bool value) {
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
                metadataLoader: widget.recentFileMetadataLoader,
                thumbnailLoader: widget.recentFileThumbnailLoader,
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
  Widget _buildClipboardTile(AppLocalizations l10n) {
    return _buildImportSourceTile(
      onTap: _handleClipboardImport,
      thumbnail: _buildClipboardPreviewGraphic(),
      details: AppText(
        l10n.fromClipboard,
        variant: AppTextVariant.bodyBold,
      ),
      trailing: const AppSvgIcon(
        icon: AppIcon.clipboardPaste,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
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
    if (_addAsLayer) {
      AppProvider.of(widget.parentContext).paste();
      return;
    }
    newDocumentFromClipboardGuarded(widget.parentContext);
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

/// A clickable import source row (the clipboard tile and each recent file):
/// a rounded square [thumbnail], the [details] beside it and a [trailing]
/// control, on the shared tile surface.
Widget _buildImportSourceTile({
  required VoidCallback onTap,
  required Widget thumbnail,
  required Widget details,
  required Widget trailing,
}) {
  return GestureDetector(
    onTap: onTap,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: DecoratedBox(
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
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: SizedBox(
                  width: AppLayout.thumbnailMaxHeight,
                  height: AppLayout.thumbnailMaxHeight,
                  child: thumbnail,
                ),
              ),
              const SizedBox(width: AppSpacing.large),
              Expanded(child: details),
              trailing,
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opens the file picker and adds the selected file as a new layer.
Future<void> _browseAndAddAsLayer(BuildContext context) async {
  final LayersProvider layers = LayersProvider.of(context);

  try {
    final PlatformFile? result = await FilePicker.pickFile(
      dialogTitle: context.l10n.fpaintLoadImage,
      windowsOptions: const WindowsOptions(lockParentWindow: true),
      linuxOptions: const LinuxOptions(lockParentWindow: true),
    );

    if (result != null && !kIsWeb) {
      final String path = result.path!;
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
  BuildContext context,
  String path,
  String? bookmark,
) async {
  final LayersProvider layers = LayersProvider.of(context);
  final ShellProvider shellProvider = ShellProvider.of(context);
  // Resolved before any await so the open never reaches back into a
  // possibly-defunct BuildContext.
  final AppPreferences preferences = AppPreferences.of(context);

  if (!await confirmDiscardIfChanged(context, layers)) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final bool success = await SecurityScopedFileService.withResolvedBookmark(
    bookmarkBase64: bookmark,
    fallbackPath: path,
    action: (String resolvedPath) => openFileFromPath(
      context: context,
      layers: layers,
      path: resolvedPath,
      preferences: preferences,
    ),
  );

  if (success) {
    await finishDocumentOpen(
      shellProvider: shellProvider,
      layers: layers,
      preferences: preferences,
      path: path,
      bookmark: bookmark,
    );
  } else if (context.mounted) {
    context.showSnackBarMessage(
      context.l10n.errorReadingFile(path),
      copyable: true,
    );
  }
}

/// Adds a recent file as a new layer, checking that the file exists.
Future<void> _addRecentAsLayer(
  BuildContext context,
  String path,
  String? bookmark,
) async {
  final LayersProvider layers = LayersProvider.of(context);

  if (!context.mounted) {
    return;
  }

  await SecurityScopedFileService.withResolvedBookmark(
    bookmarkBase64: bookmark,
    fallbackPath: path,
    action: (String resolvedPath) => addFileAsLayer(context: context, layers: layers, path: resolvedPath),
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
    required this.metadataLoader,
    required this.thumbnailLoader,
    required this.onTap,
    required this.onDiscard,
  });
  final String? bookmark;
  final RecentFileMetadataLoader? metadataLoader;
  final Future<void> Function() onDiscard;
  final VoidCallback onTap;
  final String path;
  final RecentFileThumbnailLoader? thumbnailLoader;
  @override
  State<_RecentFileEntry> createState() => _RecentFileEntryState();
}

class _RecentFileEntryState extends State<_RecentFileEntry> {
  bool _fileExists = true;
  DateTime? _lastModified;
  bool _loadFailed = false;
  ui.Image? _thumbnail;
  @override
  void initState() {
    super.initState();
    _loadFileMetadata();
    _loadThumbnail();
  }

  @override
  Widget build(BuildContext context) {
    final String fileName = widget.path.split(Platform.pathSeparator).last;
    final String parentPath = File(widget.path).parent.path;
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: _buildImportSourceTile(
        onTap: widget.onTap,
        thumbnail: _buildThumbnail(),
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppText(fileName, variant: AppTextVariant.bodyBold),
            AppText(parentPath, variant: AppTextVariant.subtitle),
            if (_lastModified != null)
              AppText(
                _formatLastModified(context, _lastModified!),
                variant: AppTextVariant.subtitle,
              ),
          ],
        ),
        trailing: AppButtonIcon(
          tooltip: l10n.delete,
          icon: AppIcon.playlistRemove,
          onPressed: () {
            widget.onDiscard();
          },
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
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppSvgIcon(
                icon: AppIcon.image,
                size: AppLayout.recentFileMissingIconSize,
              ),
              const SizedBox(height: AppSpacing.small),
              Flexible(
                child: AppText(
                  label,
                  variant: AppTextVariant.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: AppMath.pair,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const AppProgressIndicator();
  }

  /// Runs [load], logging [failureMessage] and applying [onFailure] as a state
  /// update when it throws.
  Future<void> _guardedLoad({
    required Future<void> Function() load,
    required String failureMessage,
    required VoidCallback onFailure,
  }) async {
    try {
      await load();
    } catch (e, stackTrace) {
      _log.warning(failureMessage, e, stackTrace);
      if (mounted) {
        setState(onFailure);
      }
    }
  }

  /// Loads non-thumbnail MRU metadata such as file existence and modified time.
  Future<void> _loadFileMetadata() {
    final RecentFileMetadataLoader? metadataLoader = widget.metadataLoader;
    return _guardedLoad(
      failureMessage: _logMetadataFailed,
      onFailure: () => _lastModified = null,
      load: () async {
        if (metadataLoader != null) {
          final RecentFileMetadata metadata = await metadataLoader(widget.path, widget.bookmark);
          if (mounted) {
            setState(() {
              _fileExists = metadata.exists;
              _lastModified = metadata.lastModified;
            });
          }
          return;
        }
        await _withResolvedFile((File file) async {
          if (!await file.exists()) {
            if (mounted) {
              setState(() {
                _fileExists = false;
                _lastModified = null;
              });
            }
            return;
          }

          final DateTime lastModified = await file.lastModified();
          if (mounted) {
            setState(() {
              _fileExists = true;
              _lastModified = lastModified;
            });
          }
        });
      },
    );
  }

  /// Asynchronously decodes the image file and scales it to a thumbnail.
  Future<void> _loadThumbnail() {
    final RecentFileThumbnailLoader? thumbnailLoader = widget.thumbnailLoader;
    return _guardedLoad(
      failureMessage: _logThumbnailFailed,
      onFailure: () => _loadFailed = true,
      load: () async {
        if (thumbnailLoader != null) {
          final ui.Image? thumbnail = await thumbnailLoader(widget.path, widget.bookmark);
          if (!mounted) {
            thumbnail?.dispose();
            return;
          }
          setState(() {
            _thumbnail = thumbnail;
            _loadFailed = thumbnail == null;
          });
          return;
        }
        await _withResolvedFile((File file) async {
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
            path: file.path,
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
        });
      },
    );
  }

  /// Runs [action] on this entry's file, resolved through its security-scoped
  /// bookmark when it has one.
  Future<void> _withResolvedFile(Future<void> Function(File) action) {
    return SecurityScopedFileService.withResolvedBookmark(
      bookmarkBase64: widget.bookmark,
      fallbackPath: widget.path,
      action: (String resolvedPath) => action(File(resolvedPath)),
    );
  }
}

/// Formats [lastModified] using the active locale's short date and time.
String _formatLastModified(
  BuildContext context,
  DateTime lastModified,
) {
  final flutter_material.MaterialLocalizations materialLocalizations = flutter_material.MaterialLocalizations.of(
    context,
  );
  final bool alwaysUse24HourFormat = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;
  final String shortDate = materialLocalizations.formatShortDate(lastModified);
  final String shortTime = materialLocalizations.formatTimeOfDay(
    flutter_material.TimeOfDay.fromDateTime(lastModified),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
  return '$shortDate $shortTime';
}
