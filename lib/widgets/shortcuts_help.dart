import 'package:flutter/material.dart';
import 'package:fpaint/helpers/constants.dart';

const String _titleKeyboardShortcuts = 'Keyboard Shortcuts';
const String _categoryFileOperations = 'File Operations';
const String _categoryEditing = 'Editing';
const String _categoryView = 'View';
const String _categoryTools = 'Tools';
const String _categoryLayers = 'Layers';
const String _actionSave = 'Save';
const String _actionOpen = 'Open';
const String _actionNewCanvas = 'New Canvas';
const String _actionUndo = 'Undo';
const String _actionRedo = 'Redo';
const String _actionCut = 'Cut';
const String _actionCopy = 'Copy';
const String _actionPaste = 'Paste';
const String _actionZoomIn = 'Zoom In';
const String _actionZoomOut = 'Zoom Out';
const String _actionResetZoom = 'Reset Zoom';
const String _actionBrushTool = 'Brush Tool';
const String _actionEraserTool = 'Eraser Tool';
const String _actionSelectionTool = 'Selection Tool';
const String _actionFillTool = 'Fill Tool';
const String _actionTextTool = 'Text Tool';
const String _actionNewLayer = 'New Layer';
const String _actionDuplicateLayer = 'Duplicate Layer';
const String _actionDeleteLayer = 'Delete Layer';
const String _labelDelete = 'Delete';
const String _labelClose = 'Close';
const String _platformCmd = 'Cmd';
const String _platformCtrl = 'Ctrl';
const String _keyB = 'B';
const String _keyC = 'C';
const String _keyD = 'D';
const String _keyE = 'E';
const String _keyF = 'F';
const String _keyN = 'N';
const String _keyO = 'O';
const String _keyS = 'S';
const String _keyT = 'T';
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

    return AlertDialog(
      title: const Text(_titleKeyboardShortcuts),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.xxl,
          children: <Widget>[
            _buildShortcutGroup(
              _categoryFileOperations,
              <Map<String, String>>[
                <String, String>{'keys': '$mod $_keyS', 'description': _actionSave},
                <String, String>{'keys': '$mod $_keyO', 'description': _actionOpen},
                <String, String>{'keys': '$mod $_keyN', 'description': _actionNewCanvas},
              ],
            ),
            _buildShortcutGroup(
              _categoryEditing,
              <Map<String, String>>[
                <String, String>{'keys': '$mod $_keyZ', 'description': _actionUndo},
                <String, String>{'keys': '$mod $_keyY', 'description': _actionRedo},
                <String, String>{'keys': '$mod $_keyX', 'description': _actionCut},
                <String, String>{'keys': '$mod $_keyC', 'description': _actionCopy},
                <String, String>{'keys': '$mod $_keyV', 'description': _actionPaste},
              ],
            ),
            _buildShortcutGroup(
              _categoryView,
              <Map<String, String>>[
                <String, String>{'keys': '$mod +', 'description': _actionZoomIn},
                <String, String>{'keys': '$mod -', 'description': _actionZoomOut},
                <String, String>{'keys': '$mod 0', 'description': _actionResetZoom},
              ],
            ),
            _buildShortcutGroup(
              _categoryTools,
              <Map<String, String>>[
                <String, String>{'keys': _keyB, 'description': _actionBrushTool},
                <String, String>{'keys': _keyE, 'description': _actionEraserTool},
                <String, String>{'keys': _keyS, 'description': _actionSelectionTool},
                <String, String>{'keys': _keyF, 'description': _actionFillTool},
                <String, String>{'keys': _keyT, 'description': _actionTextTool},
              ],
            ),
            _buildShortcutGroup(
              _categoryLayers,
              <Map<String, String>>[
                <String, String>{
                  'keys': '$mod $_modShift $_keyN',
                  'description': _actionNewLayer,
                },
                <String, String>{
                  'keys': '$mod $_modShift $_keyD',
                  'description': _actionDuplicateLayer,
                },
                <String, String>{
                  'keys': _labelDelete,
                  'description': _actionDeleteLayer,
                },
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(_labelClose),
        ),
      ],
    );
  }

  /// Builds a single shortcut row with key caps and description text.
  Widget _buildShortcut(final String keys, final String description) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: Colors.grey.shade600),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  /// Builds the section title for a shortcut category.
  Widget _buildShortcutCategory(final String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: AppSpacing.xl,
        ),
      ),
    );
  }

  /// Builds a fixed-width group of shortcuts under a category heading.
  Widget _buildShortcutGroup(
    final String title,
    final List<Map<String, String>> shortcuts,
  ) {
    return SizedBox(
      width: AppLayout.shortcutGroupWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildShortcutCategory(title),
          ...shortcuts.map(
            (final Map<String, String> shortcut) => _buildShortcut(shortcut['keys']!, shortcut['description']!),
          ),
        ],
      ),
    );
  }

  String _getPlatformModifier(final BuildContext context) {
    final bool isMacOS =
        Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.iOS;
    return isMacOS ? _platformCmd : _platformCtrl;
  }
}
