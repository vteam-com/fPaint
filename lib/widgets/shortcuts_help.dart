import 'package:flutter/material.dart';

class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  String _getPlatformModifier(final BuildContext context) {
    final bool isMacOS =
        Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.iOS;
    return isMacOS ? 'Cmd' : 'Ctrl';
  }

  @override
  Widget build(final BuildContext context) {
    final String mod = _getPlatformModifier(context);

    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SingleChildScrollView(
        child: Wrap(
          spacing: 20.0,
          runSpacing: 20.0,
          children: <Widget>[
            _buildShortcutGroup(
              'File Operations',
              <Map<String, String>>[
                <String, String>{'keys': '$mod S', 'description': 'Save'},
                <String, String>{'keys': '$mod O', 'description': 'Open'},
                <String, String>{'keys': '$mod N', 'description': 'New Canvas'},
              ],
            ),
            _buildShortcutGroup(
              'Editing',
              <Map<String, String>>[
                <String, String>{'keys': '$mod Z', 'description': 'Undo'},
                <String, String>{'keys': '$mod Y', 'description': 'Redo'},
                <String, String>{'keys': '$mod X', 'description': 'Cut'},
                <String, String>{'keys': '$mod C', 'description': 'Copy'},
                <String, String>{'keys': '$mod V', 'description': 'Paste'},
              ],
            ),
            _buildShortcutGroup(
              'View',
              <Map<String, String>>[
                <String, String>{'keys': '$mod +', 'description': 'Zoom In'},
                <String, String>{'keys': '$mod -', 'description': 'Zoom Out'},
                <String, String>{'keys': '$mod 0', 'description': 'Reset Zoom'},
              ],
            ),
            _buildShortcutGroup(
              'Tools',
              <Map<String, String>>[
                <String, String>{'keys': 'B', 'description': 'Brush Tool'},
                <String, String>{'keys': 'E', 'description': 'Eraser Tool'},
                <String, String>{'keys': 'S', 'description': 'Selection Tool'},
                <String, String>{'keys': 'F', 'description': 'Fill Tool'},
                <String, String>{'keys': 'T', 'description': 'Text Tool'},
              ],
            ),
            _buildShortcutGroup(
              'Layers',
              <Map<String, String>>[
                <String, String>{
                  'keys': '$mod Shift N',
                  'description': 'New Layer',
                },
                <String, String>{
                  'keys': '$mod Shift D',
                  'description': 'Duplicate Layer',
                },
                <String, String>{
                  'keys': 'Delete',
                  'description': 'Delete Layer',
                },
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildShortcutCategory(final String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildShortcut(final String keys, final String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4.0),
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
          const SizedBox(width: 16.0),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }

  Widget _buildShortcutGroup(
    final String title,
    final List<Map<String, String>> shortcuts,
  ) {
    return SizedBox(
      width: 250,
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
}
