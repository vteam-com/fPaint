import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Keyboard cause used for text selection shortcut intents.
const SelectionChangedCause _kKeyboardSelectionCause = SelectionChangedCause.keyboard;

/// A text input field replacing Material [TextField].
///
/// Wraps [EditableText] with border, hint text, focus management, and full
/// text selection support: visible selection highlight, click-to-place-cursor,
/// drag selection, double-click word selection, and select-all shortcuts.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.style,
    this.textAlign = TextAlign.start,
    this.selectAllOnFocus = false,
  });
  final bool autofocus;
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// When true, clicking into an unfocused field selects its entire content
  /// so typing replaces the current value (numeric-input convention).
  final bool selectAllOnFocus;

  final TextStyle? style;
  final TextAlign textAlign;
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> implements TextSelectionGestureDetectorBuilderDelegate {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late final _AppTextFieldGestureBuilder _gestureBuilder = _AppTextFieldGestureBuilder(state: this);
  late bool _isTextEmpty;
  bool _ownsController = false;
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey<EditableTextState>();
  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    _focusNode = FocusNode();
    _isTextEmpty = _controller.text.isEmpty;
    _controller.addListener(_onTextChanged);
    if (widget.autofocus && widget.selectAllOnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted && _focusNode.hasFocus) {
          _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = TextEditingController();
        _ownsController = true;
      }
      _isTextEmpty = _controller.text.isEmpty;
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle effectiveStyle = widget.style ?? AppTextStyle.input;

    return _gestureBuilder.buildGestureDetector(
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                if (_isTextEmpty && widget.hintText != null)
                  IgnorePointer(
                    child: Text(
                      widget.hintText!,
                      style: effectiveStyle.copyWith(color: AppColors.textDisabled),
                    ),
                  ),
                Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.backspace): DeleteCharacterIntent(forward: false),
                    SingleActivator(LogicalKeyboardKey.delete): DeleteCharacterIntent(forward: true),
                    SingleActivator(LogicalKeyboardKey.keyA, meta: true): SelectAllTextIntent(_kKeyboardSelectionCause),
                    SingleActivator(LogicalKeyboardKey.keyA, control: true): SelectAllTextIntent(
                      _kKeyboardSelectionCause,
                    ),
                  },
                  child: EditableText(
                    key: editableTextKey,
                    controller: _controller,
                    focusNode: _focusNode,
                    style: effectiveStyle,
                    cursorColor: AppColors.primary,
                    backgroundCursorColor: AppColors.surfaceVariant,
                    selectionColor: AppColors.textSelection,
                    rendererIgnoresPointer: true,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    autofocus: widget.autofocus,
                    textAlign: widget.textAlign,
                    keyboardType: widget.keyboardType,
                    onSubmitted: widget.onSubmitted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get forcePressEnabled => false;
  @override
  bool get selectionEnabled => true;
  void _onTextChanged() {
    final bool nextIsEmpty = _controller.text.isEmpty;
    if (_isTextEmpty != nextIsEmpty) {
      setState(() {
        _isTextEmpty = nextIsEmpty;
      });
    }
    widget.onChanged?.call(_controller.text);
  }
}

/// Selection gesture handling for [AppTextField].
///
/// The base builder maps taps, drags, and double-clicks to selection changes;
/// this subclass additionally requests keyboard focus on tap and applies the
/// select-all-on-first-click behavior when [AppTextField.selectAllOnFocus] is
/// set.
class _AppTextFieldGestureBuilder extends TextSelectionGestureDetectorBuilder {
  _AppTextFieldGestureBuilder({required _AppTextFieldState state}) : _state = state, super(delegate: state);
  final _AppTextFieldState _state;
  bool _hadFocusOnTapDown = false;

  @override
  void onTapDown(TapDragDownDetails details) {
    _hadFocusOnTapDown = _state._focusNode.hasFocus;
    super.onTapDown(details);
  }

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    super.onSingleTapUp(details);
    final EditableTextState? editable = _state.editableTextKey.currentState;
    if (editable == null) {
      return;
    }
    editable.requestKeyboard();
    if (_state.widget.selectAllOnFocus && !_hadFocusOnTapDown) {
      editable.selectAll(SelectionChangedCause.tap);
    }
  }
}
