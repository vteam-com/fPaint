import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/models/text_object.dart';
import 'package:fpaint/models/text_tool_state.dart';
import 'package:fpaint/models/user_action_drawing.dart';
import 'package:fpaint/providers/app_provider.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/text_editor_dialog.dart';

/// Opens the text editing flow for the currently selected text object.
class TextEditor extends StatefulWidget {
  const TextEditor({super.key});

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late final AppProvider appProvider;

  late final TextObject textObject;

  @override
  void initState() {
    super.initState();
    appProvider = AppProvider.of(context);
    textObject = appProvider.selectedTextObject!;

    // Show the edit dialog immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showEditTextDialog();
    });
  }

  @override
  Widget build(final BuildContext context) {
    // Return an empty container since the dialog handles everything
    return const SizedBox.shrink();
  }

  void _deleteText() {
    // Find and remove the text object from the action stack
    final List<UserActionDrawing> actionStack = appProvider.layers.selectedLayer.actionStack;
    actionStack.removeWhere((final UserActionDrawing action) => action.textObject == textObject);

    appProvider.selectedTextObject = null;
    appProvider.layers.selectedLayer.clearCache();
    appProvider.update();
  }

  /// Displays the text editing dialog for the currently selected text object.
  void _showEditTextDialog() {
    final AppLocalizations l10n = context.l10n;

    showAppBottomSheet<void>(
      context: context,
      barrierColor: AppColors.transparent,
      builder: (final BuildContext _) {
        return TextEditorDialog(
          title: l10n.editText,
          submitLabel: l10n.apply,
          position: textObject.position,
          initialText: textObject.text,
          initialStyle: TextToolState.fromTextObject(textObject),
          onDelete: () {
            _deleteText();
          },
          onSubmitted: (final TextObject updatedTextObject) {
            textObject.text = updatedTextObject.text;
            textObject.position = updatedTextObject.position;
            textObject.size = updatedTextObject.size;
            textObject.color = updatedTextObject.color;
            textObject.fontWeight = updatedTextObject.fontWeight;
            textObject.fontStyle = updatedTextObject.fontStyle;
            textObject.textAlign = updatedTextObject.textAlign;
            appProvider.selectedTextObject = null;
            appProvider.adoptTextToolStateFromObject(updatedTextObject);
            appProvider.update();
          },
        );
      },
    ).then((_) {
      if (!mounted || appProvider.selectedTextObject != textObject) {
        return;
      }
      appProvider.selectedTextObject = null;
      appProvider.update();
    });
  }
}
