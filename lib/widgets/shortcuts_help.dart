import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/widgets/material_free.dart';

const String _categoryFileOperations = 'File Operations';
const String _categoryEditing = 'Editing';
const String _categoryView = 'View';
const String _categoryTools = 'Tools';
const String _categoryLayers = 'Layers';
const String _categorySelection = 'Selection';
const String _actionSave = 'Save';
const String _actionOpen = 'Open';
const String _actionNewCanvas = 'New Canvas';
const String _actionUndo = 'Undo';
const String _actionRedo = 'Redo';
const String _actionCut = 'Cut';
const String _actionCopy = 'Copy';
const String _actionPaste = 'Paste';
const String _actionDuplicateSameLayer = 'Duplicate in Same Layer';
const String _actionDuplicateNewLayer = 'Duplicate on New Layer';
const String _actionDragSelection = 'Drag Selection';
const String _actionZoomIn = 'Zoom In';
const String _actionZoomOut = 'Zoom Out';
const String _actionResetZoom = 'Reset Zoom';
const String _actionShowKeyboardShortcutsKeys = 'Ctrl /, F1';
const String _actionBrushTool = 'Brush Tool';
const String _actionEraserTool = 'Eraser Tool';
const String _actionSelectionTool = 'Selection Tool';
const String _actionFillTool = 'Fill Tool';
const String _actionTextTool = 'Text Tool';
const String _actionAddToSelection = 'Add to Selection';
const String _actionSubtractFromSelection = 'Subtract from Selection';
const String _actionIntersectWithSelection = 'Intersect with Selection';
const String _actionWandSampleAllLayers = 'Magic Wand: Sample All Layers';
const String _actionFloodFillSampleAllLayers = 'Flood Fill: Sample All Layers';
const String _actionNewLayer = 'New Layer';
const String _actionDeleteLayer = 'Delete Layer';
const String _labelDelete = 'Delete';
const String _labelClose = 'Close';
const String _platformCmd = 'Cmd';
const String _platformCtrl = 'Ctrl';
const String _platformOption = 'Option';
const String _platformAlt = 'Alt';
const String _keyB = 'B';
const String _keyC = 'C';
const String _keyD = 'D';
const String _keyE = 'E';
const String _keyF = 'F';
const String _keyN = 'N';
const String _keyO = 'O';
const String _keyS = 'S';
const String _keyT = 'T';
const String _keyTab = 'Tab';
const String _keyV = 'V';
const String _keyX = 'X';
const String _keyY = 'Y';
const String _keyZ = 'Z';
const String _modShift = 'Shift';

/// Displays an overview of keyboard shortcuts in a modal dialog.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});
  @override
  Widget build(final BuildContext context) {
    final String mod = _getPlatformModifier(context);
    final String moveDuplicateModifier = _getMoveDuplicateModifier();
    final String duplicateMoveNewLayerShortcut = '$_modShift + $moveDuplicateModifier + $_actionDragSelection';
    final AppLocalizations l10n = context.l10n;
    final List<({String title, List<Map<String, String>> shortcuts})> shortcutGroups =
        <({String title, List<Map<String, String>> shortcuts})>[
          (
            title: _categoryFileOperations,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod $_keyS', 'description': _actionSave},
              <String, String>{'keys': '$mod $_keyO', 'description': _actionOpen},
              <String, String>{'keys': '$mod $_keyN', 'description': _actionNewCanvas},
            ],
          ),
          (
            title: _categoryEditing,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod $_keyZ', 'description': _actionUndo},
              <String, String>{'keys': '$mod $_keyY', 'description': _actionRedo},
              <String, String>{'keys': '$mod $_keyX', 'description': _actionCut},
              <String, String>{'keys': '$mod $_keyC', 'description': _actionCopy},
              <String, String>{'keys': '$mod $_keyV', 'description': _actionPaste},
              <String, String>{'keys': '$mod $_keyD', 'description': _actionDuplicateSameLayer},
              <String, String>{'keys': '$mod $_modShift $_keyD', 'description': _actionDuplicateNewLayer},
              <String, String>{
                'keys': '$moveDuplicateModifier + $_actionDragSelection',
                'description': _actionDuplicateSameLayer,
              },
              <String, String>{
                'keys': duplicateMoveNewLayerShortcut,
                'description': _actionDuplicateNewLayer,
              },
            ],
          ),
          (
            title: _categoryView,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod +', 'description': _actionZoomIn},
              <String, String>{'keys': '$mod -', 'description': _actionZoomOut},
              <String, String>{'keys': '$mod 0', 'description': _actionResetZoom},
              <String, String>{'keys': _keyTab, 'description': l10n.toggleShell},
              <String, String>{'keys': _actionShowKeyboardShortcutsKeys, 'description': l10n.keyboardShortcuts},
            ],
          ),
          (
            title: _categoryTools,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': _keyB, 'description': _actionBrushTool},
              <String, String>{'keys': _keyE, 'description': _actionEraserTool},
              <String, String>{'keys': _keyS, 'description': _actionSelectionTool},
              <String, String>{'keys': _keyF, 'description': _actionFillTool},
              <String, String>{'keys': _keyT, 'description': _actionTextTool},
            ],
          ),
          (
            title: _categorySelection,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': _modShift, 'description': _actionAddToSelection},
              <String, String>{'keys': _getSelectionSubtractModifier(), 'description': _actionSubtractFromSelection},
              <String, String>{
                'keys': '$_modShift + ${_getSelectionSubtractModifier()}',
                'description': _actionIntersectWithSelection,
              },
              <String, String>{'keys': _getPlatformModifier(context), 'description': _actionWandSampleAllLayers},
              <String, String>{'keys': _getPlatformModifier(context), 'description': _actionFloodFillSampleAllLayers},
            ],
          ),
          (
            title: _categoryLayers,
            shortcuts: <Map<String, String>>[
              <String, String>{'keys': '$mod $_modShift $_keyN', 'description': _actionNewLayer},
              <String, String>{'keys': _labelDelete, 'description': _actionDeleteLayer},
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
          text: _labelClose,
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
    return isMacOS ? _platformOption : _platformCtrl;
  }

  String _getSelectionSubtractModifier() {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return isMacOS ? _platformOption : _platformAlt;
  }

  String _getPlatformModifier(final BuildContext _) {
    final bool isMacOS = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return isMacOS ? _platformCmd : _platformCtrl;
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
