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
              <String, String>{'keys': '$mod ${ShortcutKeys.s}', 'description': ShortcutActions.save},
              <String, String>{'keys': '$mod ${ShortcutKeys.o}', 'description': ShortcutActions.open},
              <String, String>{'keys': '$mod ${ShortcutKeys.n}', 'description': ShortcutActions.newCanvas},
            ],
          ),
          (
            title: ShortcutCategories.editing,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod ${ShortcutKeys.z}', 'description': ShortcutActions.undo},
              <String, String>{'keys': '$mod ${ShortcutKeys.y}', 'description': ShortcutActions.redo},
              <String, String>{'keys': '$mod ${ShortcutKeys.x}', 'description': ShortcutActions.cut},
              <String, String>{'keys': '$mod ${ShortcutKeys.c}', 'description': ShortcutActions.copy},
              <String, String>{'keys': '$mod ${ShortcutKeys.v}', 'description': ShortcutActions.paste},
              <String, String>{'keys': '$mod ${ShortcutKeys.d}', 'description': ShortcutActions.duplicateSameLayer},
              <String, String>{
                'keys': '$mod ${ShortcutModifiers.shift} ${ShortcutKeys.d}',
                'description': ShortcutActions.duplicateNewLayer,
              },
              <String, String>{
                'keys': '$moveDuplicateModifier + ${ShortcutActions.dragSelection}',
                'description': ShortcutActions.duplicateSameLayer,
              },
              <String, String>{
                'keys': duplicateMoveNewLayerShortcut,
                'description': ShortcutActions.duplicateNewLayer,
              },
            ],
          ),
          (
            title: ShortcutCategories.view,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod +', 'description': ShortcutActions.zoomIn},
              <String, String>{'keys': '$mod -', 'description': ShortcutActions.zoomOut},
              <String, String>{'keys': '$mod 0', 'description': ShortcutActions.resetZoom},
              <String, String>{'keys': ShortcutKeys.tab, 'description': l10n.toggleShell},
              <String, String>{'keys': ShortcutActions.showKeyboardShortcuts, 'description': l10n.keyboardShortcuts},
            ],
          ),
          (
            title: ShortcutCategories.tools,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': ShortcutKeys.b, 'description': ShortcutActions.brushTool},
              <String, String>{'keys': ShortcutKeys.e, 'description': ShortcutActions.eraserTool},
              <String, String>{'keys': ShortcutKeys.s, 'description': ShortcutActions.selectionTool},
              <String, String>{'keys': ShortcutKeys.f, 'description': ShortcutActions.fillTool},
              <String, String>{'keys': ShortcutKeys.t, 'description': ShortcutActions.textTool},
            ],
          ),
          (
            title: ShortcutCategories.selection,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': ShortcutModifiers.shift, 'description': ShortcutActions.addToSelection},
              <String, String>{
                'keys': _getSelectionSubtractModifier(),
                'description': ShortcutActions.subtractFromSelection,
              },
              <String, String>{
                'keys': '${ShortcutModifiers.shift} + ${_getSelectionSubtractModifier()}',
                'description': ShortcutActions.intersectWithSelection,
              },
              <String, String>{
                'keys': _getPlatformModifier(context),
                'description': ShortcutActions.wandSampleAllLayers,
              },
              <String, String>{
                'keys': _getPlatformModifier(context),
                'description': ShortcutActions.floodFillSampleAllLayers,
              },
            ],
          ),
          (
            title: ShortcutCategories.layers,
            shortcuts: <Map<String, String>>[
              <String, String>{
                'keys': '$mod ${ShortcutModifiers.shift} ${ShortcutKeys.n}',
                'description': ShortcutActions.newLayer,
              },
              <String, String>{'keys': ShortcutLabels.delete, 'description': ShortcutActions.deleteLayer},
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
            shortcut['keys']!,
            shortcut['description']!,
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
