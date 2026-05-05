import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/fill_model.dart';
import 'package:fpaint/widgets/app_buttons.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/app_text_field.dart';
import 'package:fpaint/widgets/color_picker_dialog.dart';
import 'package:fpaint/widgets/color_preview.dart';

/// The maximum integer percentage value a gradient stop may take.
const int _kMaxStopPercent = 100;

/// A panel widget that lets the user manage the ordered list of color stops
/// for a gradient fill (linear or radial).
///
/// The editor shows one row per stop.  Each row contains:
///   * Up / Down arrow buttons to reorder the stop.
///   * A color-preview swatch that opens a color-picker on tap.
///   * A percentage field showing the stop's position (0–100 %).
///     The first stop is fixed at 0 % and the last at 100 %.
///     Inner stops are freely editable.
///   * A remove button (disabled when only [FillModel.gradientStopMin] stops remain).
///
/// An "Add color stop" button beneath the list inserts a new stop copied from
/// the last existing stop, with its position automatically distributed evenly.
///
/// Every mutation calls [onChanged] so the caller can propagate the update
/// (e.g. refresh the gradient fill on the canvas).
class GradientColorListEditor extends StatefulWidget {
  const GradientColorListEditor({
    super.key,
    required this.fillModel,
    required this.onChanged,
  });

  /// The fill model whose [FillModel.gradientStopColors] and
  /// [FillModel.gradientStopPositions] this editor manages.
  final FillModel fillModel;

  /// Called after every mutation so the caller can refresh the gradient.
  final VoidCallback onChanged;

  @override
  State<GradientColorListEditor> createState() => _GradientColorListEditorState();
}

class _GradientColorListEditorState extends State<GradientColorListEditor> {
  /// One controller per stop for the position text fields.
  final List<TextEditingController> _posControllers = <TextEditingController>[];
  @override
  void initState() {
    super.initState();
    _ensureEndpointPositions();
    _syncPositionControllers();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _posControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(final GradientColorListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool stopCountChanged = oldWidget.fillModel.gradientStopPositions.length != _posControllers.length;
    if (stopCountChanged || _positionTextOutOfSync()) {
      _ensureEndpointPositions();
      _syncPositionControllers();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canRemoveAny = _stops.length > FillModel.gradientStopMin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < _stops.length; i++) _buildStopRow(context, l10n, i, canRemoveAny),
        _buildAddButton(l10n),
      ],
    );
  }

  /// Inserts a new inner stop without changing existing percentages.
  ///
  /// The new stop is inserted before the fixed 100% endpoint. Its percentage
  /// is the midpoint between the previous stop and 100%, and its color is the
  /// midpoint blend between those two neighboring stop colors.
  void _addStop() {
    setState(() {
      final int insertIndex = _stops.length - 1;
      final Color lowerColor = _stops[insertIndex - 1];
      final Color upperColor = _stops.last;
      final Color insertedColor = Color.lerp(lowerColor, upperColor, AppVisual.half) ?? upperColor;
      _stops.insert(insertIndex, insertedColor);

      final double lowerBound = insertIndex > 0 ? _positions[insertIndex - 1] : AppMath.zero.toDouble();
      final double insertedPosition = (lowerBound + AppVisual.full) / AppMath.pair;
      _positions.insert(insertIndex, insertedPosition);

      _ensureEndpointPositions();
    });
    _syncPositionControllers();
    _notifyChanged();
  }

  /// Builds the "Add color stop" button shown beneath the stop list.
  Widget _buildAddButton(final AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: AppButtonIcon(
        key: Keys.gradientStopAddButton,
        icon: const AppSvgIcon(icon: AppIcon.playlistAdd),
        tooltip: l10n.gradientColorAdd,
        onPressed: _addStop,
      ),
    );
  }

  /// Builds the percentage position field for stop [index].
  ///
  /// Endpoint stops (index 0 and last) display their fixed value in a
  /// read-only style.  Inner stops use an editable [AppTextField].
  Widget _buildPositionField(final int index, final bool isEndpoint, final AppLocalizations l10n) {
    if (_posControllers.length <= index) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: AppLayout.gradientStopPositionFieldWidth,
      child: isEndpoint
          ? Text(
              '${_posControllers[index].text}%',
              key: Key('${Keys.gradientStopPositionKeyPrefixText}${index}_label'),
              style: AppTextStyle.label,
              textAlign: TextAlign.center,
            )
          : AppTextField(
              key: Key('${Keys.gradientStopPositionKeyPrefixText}$index'),
              controller: _posControllers[index],
              hintText: l10n.gradientStopPosition,
              keyboardType: const TextInputType.numberWithOptions(),
              textAlign: TextAlign.center,
              onSubmitted: (final String v) => _changePosition(index, v),
            ),
    );
  }

  /// Builds a single row for the gradient stop at [index].
  ///
  /// Shows up/down reorder arrows, a color-preview swatch, an editable
  /// position-percentage field, and (when [canRemove] is true) a remove button.
  Widget _buildStopRow(
    final BuildContext context,
    final AppLocalizations l10n,
    final int index,
    final bool canRemoveAny,
  ) {
    final Color stopColor = _stops[index];
    final bool isFirst = index == 0;
    final bool isLast = index == _stops.length - 1;
    final bool isEndpoint = isFirst || isLast;
    final bool canRemove = canRemoveAny && !isEndpoint;
    final bool canMoveUp = index > AppMath.pair - 1;
    final bool canMoveDown = index < _stops.length - AppMath.pair;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Up arrow
          _reorderButton(
            key: Key('${Keys.gradientStopColorKeyPrefixText}${index}_up'),
            icon: AppIcon.arrowUp,
            enabled: canMoveUp,
            onPressed: () => _moveUp(index),
          ),
          // Down arrow
          _reorderButton(
            key: Key('${Keys.gradientStopColorKeyPrefixText}${index}_down'),
            icon: AppIcon.arrowDown,
            enabled: canMoveDown,
            onPressed: () => _moveDown(index),
          ),
          const SizedBox(width: AppSpacing.small),
          // Color swatch
          colorPreviewWithTransparentPaper(
            key: Key('${Keys.gradientStopColorKeyPrefixText}$index'),
            minimal: true,
            color: stopColor,
            onPressed: () {
              showColorPicker(
                context: context,
                title: l10n.gradientPointColor,
                color: stopColor,
                onSelectedColor: (final Color picked) => _changeColor(index, picked),
              );
            },
          ),
          const SizedBox(width: AppSpacing.small),
          // Position percentage field
          _buildPositionField(index, isEndpoint, l10n),
          const SizedBox(width: AppSpacing.small),
          // Remove button
          if (canRemove)
            AppButtonIcon(
              key: Key('${Keys.gradientStopColorKeyPrefixText}${index}_remove'),
              icon: const AppSvgIcon(
                icon: AppIcon.close,
                isSelected: false,
              ),
              tooltip: l10n.gradientColorRemove,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: () => _removeStop(index),
            )
          else
            // Placeholder to keep alignment consistent.
            const SizedBox(width: AppLayout.iconSize),
        ],
      ),
    );
  }

  void _changeColor(final int index, final Color newColor) {
    setState(() {
      _stops[index] = newColor;
    });
    _notifyChanged();
  }

  /// Applies a new position value (entered by the user as an integer 0–100)
  /// to stop [index].  The value is clamped so it stays between the surrounding
  /// stop positions (exclusive).
  void _changePosition(final int index, final String raw) {
    if (index == AppMath.zero || index == _positions.length - 1) {
      _syncPositionControllers();
      return;
    }

    final int? parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      return;
    }
    final double lo = index > 0 ? _positions[index - 1] : 0.0;
    final double hi = index < _positions.length - 1 ? _positions[index + 1] : 1.0;
    // Inner values must lie strictly between neighbors; clamp to 1-unit steps.
    final double loPercent = index > 0 ? (lo * _kMaxStopPercent).ceilToDouble() : 0.0;
    final double hiPercent = index < _positions.length - 1
        ? (hi * _kMaxStopPercent).floorToDouble()
        : _kMaxStopPercent.toDouble();
    final double clamped = parsed.toDouble().clamp(loPercent, hiPercent);
    setState(() {
      _positions[index] = clamped / _kMaxStopPercent;
      _ensureEndpointPositions();
    });
    // Keep the controller text in sync with the clamped value.
    _posControllers[index].text = clamped.toInt().toString();
    _notifyChanged();
  }

  /// Enforces fixed endpoint stops at 0% and 100%.
  void _ensureEndpointPositions() {
    if (_positions.isEmpty) {
      return;
    }

    _positions[AppMath.zero] = AppMath.zero.toDouble();
    if (_positions.length > 1) {
      _positions[_positions.length - 1] = AppVisual.full;
    }
  }

  /// Moves the stop at [index] one position toward the end of the list.
  void _moveDown(final int index) {
    if (index >= _stops.length - AppMath.pair) {
      return;
    }
    setState(() {
      _swapStops(index, index + 1);

      _ensureEndpointPositions();
    });
    _syncPositionControllers();
    _notifyChanged();
  }

  /// Moves the stop at [index] one position toward the start of the list.
  void _moveUp(final int index) {
    if (index <= AppMath.zero + 1) {
      return;
    }
    setState(() {
      _swapStops(index - 1, index);

      _ensureEndpointPositions();
    });
    _syncPositionControllers();
    _notifyChanged();
  }

  void _notifyChanged() {
    // Keep the two canvas handles in sync with the first / last stop colors.
    if (widget.fillModel.gradientPoints.length >= AppMath.pair) {
      widget.fillModel.gradientPoints.first.color = _stops.first;
      widget.fillModel.gradientPoints.last.color = _stops.last;
    }
    widget.onChanged();
  }

  /// Returns true when any position field text differs from model values.
  bool _positionTextOutOfSync() {
    if (_posControllers.length != _positions.length) {
      return true;
    }
    for (int i = 0; i < _positions.length; i++) {
      final String expected = (_positions[i] * _kMaxStopPercent).round().toString();
      if (_posControllers[i].text != expected) {
        return true;
      }
    }
    return false;
  }

  List<double> get _positions => widget.fillModel.gradientStopPositions;

  /// Removes the stop at [index].
  ///
  /// Does nothing when only [FillModel.gradientStopMin] stops remain.
  /// Endpoint stops (0% and 100%) are never removed.
  ///
  /// Existing stop percentages remain unchanged after removal.
  void _removeStop(final int index) {
    if (_stops.length <= FillModel.gradientStopMin) {
      return;
    }
    if (index == AppMath.zero || index == _stops.length - 1) {
      return;
    }
    setState(() {
      _stops.removeAt(index);
      _positions.removeAt(index);

      _ensureEndpointPositions();
    });
    _syncPositionControllers();
    _notifyChanged();
  }

  /// Builds a small icon button used to move a stop up or down.
  ///
  /// When [enabled] is false the button is rendered at reduced opacity and its
  /// [onPressed] callback is a no-op.
  Widget _reorderButton({
    required final Key key,
    required final AppIcon icon,
    required final bool enabled,
    required final VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: enabled ? AppVisual.full : AppVisual.disabled,
      child: AppButtonIcon(
        key: key,
        icon: AppSvgIcon(icon: icon, isSelected: false),
        tooltip: null,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(AppSpacing.small),
        onPressed: enabled ? onPressed : () {},
      ),
    );
  }

  List<Color> get _stops => widget.fillModel.gradientStopColors;

  /// Swaps both color and percentage between indices [a] and [b].
  void _swapStops(final int a, final int b) {
    final Color tmpColor = _stops[b];
    _stops[b] = _stops[a];
    _stops[a] = tmpColor;

    final double tmpPos = _positions[b];
    _positions[b] = _positions[a];
    _positions[a] = tmpPos;
  }

  /// Rebuilds [_posControllers] to match the current positions list.
  void _syncPositionControllers() {
    for (final TextEditingController c in _posControllers) {
      c.dispose();
    }
    _posControllers
      ..clear()
      ..addAll(
        _positions
            .map((final double p) => TextEditingController(text: (p * _kMaxStopPercent).round().toString()))
            .toList(),
      );
  }
}
