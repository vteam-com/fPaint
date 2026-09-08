import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/helpers/shortcut_tooltip.dart';
import 'package:fpaint/helpers/shortcuts_constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/widgets/material_free.dart';

/// One shortcut row: the keys to cap, its description, an optional trailing
/// gesture (drag/twist, which has no key cap) and an optional alternate binding.
typedef _ShortcutEntry = ({
  List<String> keys,
  String description,
  String? gesture,
  List<String>? alternateKeys,
});

/// A titled group of shortcut rows.
typedef _ShortcutGroup = ({String title, List<_ShortcutEntry> shortcuts});

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
    final AppLocalizations l10n = context.l10n;
    final List<_ShortcutGroup> shortcutGroups = <_ShortcutGroup>[
      (
        title: ShortcutCategories.fileOperations,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[mod, ShortcutKeys.s], ShortcutActions.save),
          _shortcutEntry(<String>[mod, ShortcutKeys.o], ShortcutActions.open),
          _shortcutEntry(<String>[mod, ShortcutKeys.n], ShortcutActions.newCanvas),
        ],
      ),
      (
        title: ShortcutCategories.editing,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[mod, ShortcutKeys.z], ShortcutActions.undo),
          _shortcutEntry(<String>[mod, ShortcutKeys.y], ShortcutActions.redo),
          _shortcutEntry(<String>[mod, ShortcutKeys.x], ShortcutActions.cut),
          _shortcutEntry(<String>[mod, ShortcutKeys.c], ShortcutActions.copy),
          _shortcutEntry(<String>[mod, ShortcutKeys.v], ShortcutActions.paste),
          _shortcutEntry(<String>[mod, ShortcutKeys.d], ShortcutActions.duplicateSameLayer),
          _shortcutEntry(
            <String>[mod, shift, ShortcutKeys.d],
            ShortcutActions.duplicateNewLayer,
          ),
          _shortcutEntry(
            <String>[duplicateDragModifier],
            ShortcutActions.duplicateSameLayer,
            gesture: ShortcutActions.dragSelection,
          ),
          _shortcutEntry(
            <String>[shift, duplicateDragModifier],
            ShortcutActions.duplicateNewLayer,
            gesture: ShortcutActions.dragSelection,
          ),
        ],
      ),
      (
        title: ShortcutCategories.view,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[mod, ShortcutKeys.plus], ShortcutActions.zoomIn),
          _shortcutEntry(<String>[mod, ShortcutKeys.minus], ShortcutActions.zoomOut),
          _shortcutEntry(<String>[mod, ShortcutKeys.zero], ShortcutActions.fitCanvasToView),
          _shortcutEntry(<String>[ShortcutKeys.bracketLeft], ShortcutActions.rotateViewCounterClockwise),
          _shortcutEntry(<String>[ShortcutKeys.bracketRight], ShortcutActions.rotateViewClockwise),
          _shortcutEntry(
            <String>[],
            ShortcutActions.rotateViewTwist,
            gesture: ShortcutActions.twoFingerTwist,
          ),
          _shortcutEntry(
            <String>[shift],
            ShortcutActions.rotateViewDrag,
            gesture: ShortcutActions.rightDragSelection,
          ),
          _shortcutEntry(<String>[ShortcutKeys.tab], l10n.toggleShell),
          _shortcutEntry(
            <String>[controlModifierShortcutLabel(), ShortcutKeys.slash],
            l10n.keyboardShortcuts,
            alternateKeys: <String>[ShortcutKeys.f1],
          ),
        ],
      ),
      (
        title: ShortcutCategories.tools,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[ShortcutKeys.b], ShortcutActions.brushTool),
          _shortcutEntry(<String>[ShortcutKeys.e], ShortcutActions.eraserTool),
          _shortcutEntry(<String>[ShortcutKeys.s], ShortcutActions.selectionTool),
          _shortcutEntry(<String>[ShortcutKeys.f], ShortcutActions.fillTool),
          _shortcutEntry(<String>[ShortcutKeys.t], ShortcutActions.textTool),
        ],
      ),
      (
        title: ShortcutCategories.selection,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[shift], ShortcutActions.addToSelection),
          _shortcutEntry(<String>[subtractModifier], ShortcutActions.subtractFromSelection),
          _shortcutEntry(
            <String>[shift, subtractModifier],
            ShortcutActions.intersectWithSelection,
          ),
          _shortcutEntry(<String>[mod], ShortcutActions.wandSampleAllLayers),
          _shortcutEntry(<String>[mod], ShortcutActions.floodFillSampleAllLayers),
        ],
      ),
      (
        title: ShortcutCategories.layers,
        shortcuts: <_ShortcutEntry>[
          _shortcutEntry(<String>[mod, shift, ShortcutKeys.n], ShortcutActions.newLayer),
          _shortcutEntry(<String>[ShortcutLabels.delete], ShortcutActions.deleteLayer),
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
            spacing: AppSpacing.large,
            runSpacing: AppSpacing.large,
            children: shortcutGroups
                .map(
                  (_ShortcutGroup group) => SizedBox(
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

  /// Builds the separator shown between two alternative bindings for one action.
  Widget _buildAlternateSeparator() {
    return const AppText(ShortcutLabels.alternateSeparator);
  }

  /// Builds the label for a mouse or trackpad gesture, which has no key cap.
  Widget _buildGestureLabel(String gesture) {
    return AppText(gesture);
  }

  /// Builds one bordered cap for a single key.
  Widget _buildKeyCap(String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small, vertical: AppSpacing.small),
      constraints: const BoxConstraints(minWidth: AppLayout.shortcutHelpKeyCapMinWidth),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.grey800,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.grey600),
      ),
      child: AppText(
        key,
        variant: AppTextVariant.bodyBold,
      ),
    );
  }

  /// Builds a single shortcut row: description on the left, key caps flush right.
  Widget _buildShortcut(
    _ShortcutEntry shortcut, {
    required double groupWidth,
  }) {
    // Narrow groups stack the caps under the description: side by side there is
    // not enough room left for the description to stay readable.
    final bool stackKeys = groupWidth < AppLayout.shortcutHelpKeyColumnMinGroupWidth;
    final Widget description = AppText(shortcut.description);
    final Widget keys = _buildShortcutKeys(shortcut);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.large, bottom: AppSpacing.small),
      child: stackKeys
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                description,
                const SizedBox(height: AppSpacing.small),
                keys,
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: description),
                const SizedBox(width: AppSpacing.medium),
                keys,
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
    List<_ShortcutEntry> shortcuts, {
    required double groupWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildShortcutCategory(title),
        ...shortcuts.map((_ShortcutEntry shortcut) => _buildShortcut(shortcut, groupWidth: groupWidth)),
      ],
    );
  }

  /// Builds the trailing key caps: one bordered cap per key, no joining glyph.
  Widget _buildShortcutKeys(_ShortcutEntry shortcut) {
    final List<Widget> caps = <Widget>[
      for (final String key in shortcut.keys) _buildKeyCap(key),
      if (shortcut.gesture != null) _buildGestureLabel(shortcut.gesture!),
      if (shortcut.alternateKeys != null) ...<Widget>[
        _buildAlternateSeparator(),
        for (final String key in shortcut.alternateKeys!) _buildKeyCap(key),
      ],
    ];

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: caps,
    );
  }

  _ShortcutEntry _shortcutEntry(
    List<String> keys,
    String description, {
    String? gesture,
    List<String>? alternateKeys,
  }) {
    return (keys: keys, description: description, gesture: gesture, alternateKeys: alternateKeys);
  }

  double _shortcutGroupWidth(double availableWidth) {
    if (availableWidth < AppLayout.shortcutHelpTwoColumnBreakpoint) {
      return availableWidth;
    }

    return (availableWidth - AppSpacing.large) / AppMath.pair;
  }
}
