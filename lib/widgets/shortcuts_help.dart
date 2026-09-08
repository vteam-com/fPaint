import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/material_free.dart';

/// Displays an overview of keyboard shortcuts in a modal dialog.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final String mod = primaryModifierShortcutLabel();
    final String shift = shiftModifierShortcutLabel();
    // Duplicate-on-drag and selection-subtract use different modifiers off Apple platforms.
    final String duplicateDragModifier = duplicateDragModifierShortcutLabel();
    final String subtractModifier = secondaryModifierShortcutLabel();
    final String duplicateMoveNewLayerShortcut = shortcutCombination(<String>[
      shift,
      duplicateDragModifier,
      ShortcutActions.dragSelection,
    ]);
    final AppLocalizations l10n = context.l10n;
    final List<({String title, List<Map<String, String>> shortcuts})> shortcutGroups =
        <({String title, List<Map<String, String>> shortcuts})>[
          (
            title: ShortcutCategories.fileOperations,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.s]), ShortcutActions.save),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.o]), ShortcutActions.open),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.n]), ShortcutActions.newCanvas),
            ],
          ),
          (
            title: ShortcutCategories.editing,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.z]), ShortcutActions.undo),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.y]), ShortcutActions.redo),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.x]), ShortcutActions.cut),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.c]), ShortcutActions.copy),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.v]), ShortcutActions.paste),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.d]), ShortcutActions.duplicateSameLayer),
              _shortcutEntry(
                shortcutCombination(<String>[mod, shift, ShortcutKeys.d]),
                ShortcutActions.duplicateNewLayer,
              ),
              _shortcutEntry(
                shortcutCombination(<String>[duplicateDragModifier, ShortcutActions.dragSelection]),
                ShortcutActions.duplicateSameLayer,
              ),
              _shortcutEntry(duplicateMoveNewLayerShortcut, ShortcutActions.duplicateNewLayer),
            ],
          ),
          (
            title: ShortcutCategories.view,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.plus]), ShortcutActions.zoomIn),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.minus]), ShortcutActions.zoomOut),
              _shortcutEntry(shortcutCombination(<String>[mod, ShortcutKeys.zero]), ShortcutActions.resetZoom),
              _shortcutEntry(ShortcutKeys.bracketLeft, ShortcutActions.rotateViewCounterClockwise),
              _shortcutEntry(ShortcutKeys.bracketRight, ShortcutActions.rotateViewClockwise),
              _shortcutEntry(
                shortcutCombination(<String>[shift, ShortcutKeys.bracketLeft]),
                ShortcutActions.resetViewRotation,
              ),
              _shortcutEntry(ShortcutActions.twoFingerTwist, ShortcutActions.rotateViewTwist),
              _shortcutEntry(
                shortcutCombination(<String>[shift, ShortcutActions.rightDragSelection]),
                ShortcutActions.rotateViewDrag,
              ),
              _shortcutEntry(ShortcutKeys.tab, l10n.toggleShell),
              _shortcutEntry(_showKeyboardShortcutsLabel(), l10n.keyboardShortcuts),
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
              _shortcutEntry(shift, ShortcutActions.addToSelection),
              _shortcutEntry(subtractModifier, ShortcutActions.subtractFromSelection),
              _shortcutEntry(
                shortcutCombination(<String>[shift, subtractModifier]),
                ShortcutActions.intersectWithSelection,
              ),
              _shortcutEntry(mod, ShortcutActions.wandSampleAllLayers),
              _shortcutEntry(mod, ShortcutActions.floodFillSampleAllLayers),
            ],
          ),
          (
            title: ShortcutCategories.layers,
            shortcuts: <Map<String, String>>[
              _shortcutEntry(shortcutCombination(<String>[mod, shift, ShortcutKeys.n]), ShortcutActions.newLayer),
              _shortcutEntry(ShortcutLabels.delete, ShortcutActions.deleteLayer),
            ],
          ),
        ];

    return AppDialog(
      title: l10n.keyboardShortcuts,
      maxWidth: AppLayout.shortcutDialogMaxWidth,
      content: LayoutBuilder(
        builder: (BuildContext _, BoxConstraints constraints) {
          final double groupWidth = _shortcutGroupWidth(constraints.maxWidth);

          return Wrap(
            /// Builds the visual key-cap label shown before each shortcut description.
            spacing: AppSpacing.large,
            runSpacing: AppSpacing.large,
            children: shortcutGroups
                .map(
                  (({String title, List<Map<String, String>> shortcuts}) group) => SizedBox(
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

  /// Builds a single shortcut row: key cap on the left, description to its right.
  Widget _buildShortcut(
    String keys,
    String description, {
    required double groupWidth,
  }) {
    // A fixed-width gutter keeps every description starting at the same x, so a
    // cap and its label read as one pair. Narrow groups let the cap self-size
    // instead, otherwise a long label would squeeze the description away.
    final bool useKeyColumn = groupWidth >= AppLayout.shortcutHelpKeyColumnMinGroupWidth;
    final Widget keyCap = _buildShortcutKeys(keys);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.large, bottom: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (useKeyColumn)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: AppLayout.shortcutHelpKeyColumnWidth),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: keyCap,
              ),
            )
          else
            keyCap,
          const SizedBox(width: AppSpacing.medium),
          Expanded(child: AppText(description)),
        ],
      ),
    );
  }

  /// Builds the section title for a shortcut category.
  Widget _buildShortcutCategory(String title) {
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
    String title,
    List<Map<String, String>> shortcuts, {
    required double groupWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildShortcutCategory(title),
        ...shortcuts.map(
          (Map<String, String> shortcut) => _buildShortcut(
            shortcut[ShortcutMapKeys.keys]!,
            shortcut[ShortcutMapKeys.description]!,
            groupWidth: groupWidth,
          ),
        ),
      ],
    );
  }

  /// Builds the bordered key-cap chip shown before each shortcut label.
  Widget _buildShortcutKeys(String keys) {
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

  Map<String, String> _shortcutEntry(String keys, String description) {
    return <String, String>{
      ShortcutMapKeys.keys: keys,
      ShortcutMapKeys.description: description,
    };
  }

  double _shortcutGroupWidth(double availableWidth) {
    if (availableWidth < AppLayout.shortcutHelpTwoColumnBreakpoint) {
      return availableWidth;
    }

    return (availableWidth - AppSpacing.large) / AppMath.pair;
  }

  /// Builds the label for the shortcut that opens this dialog.
  String _showKeyboardShortcutsLabel() {
    final String slashShortcut = shortcutCombination(<String>[controlModifierShortcutLabel(), ShortcutKeys.slash]);
    return '$slashShortcut${ShortcutActions.showKeyboardShortcutsSeparator}${ShortcutKeys.f1}';
  }
}
