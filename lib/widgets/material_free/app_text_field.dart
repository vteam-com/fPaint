import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';

/// A text input field replacing Material [TextField].
///
/// Wraps [EditableText] with border, hint text, and focus management.
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
  });
  final bool autofocus;
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final TextAlign textAlign;
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsController = false;
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
    _controller.addListener(_onTextChanged);
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
  void didUpdateWidget(final AppTextField oldWidget) {
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
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final TextStyle effectiveStyle =
        widget.style ?? const TextStyle(color: AppPalette.white, fontSize: AppFontSize.titleHero);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            if (_controller.text.isEmpty && widget.hintText != null)
              IgnorePointer(
                child: Text(
                  widget.hintText!,
                  style: effectiveStyle.copyWith(color: AppColors.textDisabled),
                ),
              ),
            EditableText(
              controller: _controller,
              focusNode: _focusNode,
              style: effectiveStyle,
              cursorColor: AppColors.primary,
              backgroundCursorColor: AppColors.surfaceVariant,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              autofocus: widget.autofocus,
              textAlign: widget.textAlign,
              keyboardType: widget.keyboardType,
              onSubmitted: widget.onSubmitted,
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged() {
    widget.onChanged?.call(_controller.text);
  }
}
