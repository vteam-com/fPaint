import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Displays an overview of keyboard shortcuts in a modal dialog.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});
  @override
  Widget build(final BuildContext context) {
    final String mod = _getPlatformModifier(context);
    final String moveDuplicateModifier = _getMoveDuplicateModifier();
    final String duplicateMoveNewLayerShortcut =
        '${ShortcutModifiers.shift} + $moveDuplicateModifier + ${ShortcutActions.dragSelection}';
    final AppLocalizations l10n = context.l10n;
    final List<({String title, List<Map<String, String>> shortcuts})> shortcutGroups =
        <({String title, List<Map<String, String>> shortcuts})>[
          (
            title: ShortcutCategories.fileOperations,
            shortcuts: <Map<String, String>>[
              _shortcutEntry('$mod ${ShortcutKeys.s}', ShortcutActions.save),
              _shortcutEntry('$mod ${ShortcutKeys.o}', ShortcutActions.open),
              _shortcutEntry('$mod ${ShortcutKeys.n}', ShortcutActions.newCanvas),
            ],
          ),
          (
            title: ShortcutCategories.editing,
            shortcuts: <Map<String, String>>[
              _shortcutEntry('$mod ${ShortcutKeys.z}', ShortcutActions.undo),
              _shortcutEntry('$mod ${ShortcutKeys.y}', ShortcutActions.redo),
              _shortcutEntry('$mod ${ShortcutKeys.x}', ShortcutActions.cut),
              _shortcutEntry('$mod ${ShortcutKeys.c}', ShortcutActions.copy),
              _shortcutEntry('$mod ${ShortcutKeys.v}', ShortcutActions.paste),
              _shortcutEntry('$mod ${ShortcutKeys.d}', ShortcutActions.duplicateSameLayer),
              _shortcutEntry('$mod ${ShortcutModifiers.shift} ${ShortcutKeys.d}', ShortcutActions.duplicateNewLayer),
              _shortcutEntry(
                '$moveDuplicateModifier + ${ShortcutActions.dragSelection}',
                ShortcutActions.duplicateSameLayer,
              ),
              _shortcutEntry(duplicateMoveNewLayerShortcut, ShortcutActions.duplicateNewLayer),
            ],
          ),
          (
            title: ShortcutCategories.view,
            shortcuts: <Map<String, String>>[
              _shortcutEntry('$mod +', ShortcutActions.zoomIn),
              _shortcutEntry('$mod -', ShortcutActions.zoomOut),
              _shortcutEntry('$mod 0', ShortcutActions.resetZoom),
              _shortcutEntry(ShortcutKeys.tab, l10n.toggleShell),
              _shortcutEntry(ShortcutActions.showKeyboardShortcuts, l10n.keyboardShortcuts),
            ],
          ),
          (
            title: ShortcutCategories.tools,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(ShortcutKeys.b, ShortcutActions.brushTool),
              _shortcutEntry(ShortcutKeys.e, ShortcutActions.eraserTool),
              _shortcutEntry(ShortcutKeys.s, ShortcutActions.selectionTool),
              _shortcutEntry(ShortcutKeys.f, ShortcutActions.fillTool),
              _shortcutEntry(ShortcutKeys.t, ShortcutActions.textTool),
            ],
          ),
          (
            title: ShortcutCategories.selection,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(ShortcutModifiers.shift, ShortcutActions.addToSelection),
              _shortcutEntry(_getSelectionSubtractModifier(), ShortcutActions.subtractFromSelection),
              _shortcutEntry(
                '${ShortcutModifiers.shift} + ${_getSelectionSubtractModifier()}',
                ShortcutActions.intersectWithSelection,
              ),
              _shortcutEntry(_getPlatformModifier(context), ShortcutActions.wandSampleAllLayers),
              _shortcutEntry(_getPlatformModifier(context), ShortcutActions.floodFillSampleAllLayers),
            ],
          ),
          (
            title: ShortcutCategories.layers,
            shortcuts: <Map<String, String>>[
              _shortcutEntry('$mod ${ShortcutModifiers.shift} ${ShortcutKeys.n}', ShortcutActions.newLayer),
              _shortcutEntry(ShortcutLabels.delete, ShortcutActions.deleteLayer),
            ],
          ),
        ];

    return AppDialog(
      title: l10n.keyboardShortcuts,
      maxWidth: AppLayout.shortcutDialogMaxWidth,
      content: LayoutBuilder(
        builder: (final BuildContext _, final BoxConstraints constraints) {
          final double groupWidth = _shortcutGroupWidth(constraints.maxWidth);

          return Wrap(
            /// Builds the visual key-cap label shown before each shortcut description.
            spacing: AppSpacing.large,
            runSpacing: AppSpacing.large,
            children: shortcutGroups
                .map(
                  (final ({String title, List<Map<String, String>> shortcuts}) group) => SizedBox(
                    width: groupWidth,
                    child: _buildShortcutGroup(
                      group.title,
                      group.shortcuts,
                      groupWidth: groupWidth,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      actions: <Widget>[
        AppRowSecondaryButton(
          onPressed: () => Navigator.of(context).pop(),
          text: ShortcutLabels.close,
        ),
      ],
    );
  }

  /// Builds a single shortcut row with key caps and description text.
  Widget _buildShortcut(
    final String keys,
    final String description, {
    required final double groupWidth,
  }) {
    final bool shouldStack = _shouldStackShortcutRow(keys, groupWidth);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.large, bottom: AppSpacing.small),
      child: shouldStack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildShortcutKeys(keys),
                const SizedBox(height: AppSpacing.small),
                AppText(description),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildShortcutKeys(keys),
                const SizedBox(width: AppSpacing.large),
                Expanded(child: AppText(description)),
              ],
            ),
    );
  }

  /// Builds the section title for a shortcut category.
  Widget _buildShortcutCategory(final String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: AppText(
        title,
        variant: AppTextVariant.title,
      ),
    );
  }

  /// Builds a fixed-width group of shortcuts under a category heading.
  Widget _buildShortcutGroup(
    final String title,
    final List<Map<String, String>> shortcuts, {
    required final double groupWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildShortcutCategory(title),
        ...shortcuts.map(
          (final Map<String, String> shortcut) => _buildShortcut(
            shortcut[ShortcutMapKeys.keys]!,
            shortcut[ShortcutMapKeys.description]!,
            groupWidth: groupWidth,
          ),
        ),
      ],
    );
  }

  /// Builds the bordered key-cap chip shown before each shortcut label.
  Widget _buildShortcutKeys(final String keys) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small, vertical: AppSpacing.small),
      decoration: BoxDecoration(
        color: AppColors.grey800,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.grey600),
      ),
      child: AppText(
        keys,
        variant: AppTextVariant.bodyBold,
      ),
    );
  }

  String _getMoveDuplicateModifier() {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return isMacOS ? ShortcutModifiers.option : ShortcutModifiers.ctrl;
  }

  String _getPlatformModifier(final BuildContext _) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return isMacOS ? ShortcutModifiers.cmd : ShortcutModifiers.ctrl;
  }

  String _getSelectionSubtractModifier() {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return isMacOS ? ShortcutModifiers.option : ShortcutModifiers.alt;
  }

  Map<String, String> _shortcutEntry(final String keys, final String description) {
    return <String, String>{
      ShortcutMapKeys.keys: keys,
      ShortcutMapKeys.description: description,
    };
  }

  double _shortcutGroupWidth(final double availableWidth) {
    if (availableWidth < AppLayout.shortcutHelpTwoColumnBreakpoint) {
      return availableWidth;
    }

    return (availableWidth - AppSpacing.large) / AppMath.pair;
  }

  bool _shouldStackShortcutRow(final String keys, final double groupWidth) {
    return groupWidth < AppLayout.shortcutHelpRowStackBreakpoint ||
        keys.length > AppLayout.shortcutHelpInlineKeyMaxCharacters;
  }
}
