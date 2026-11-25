import 'package:flutter/widgets.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/base_picker.dart';
import 'package:fpaint/widgets/brush_library.dart';
import 'package:fpaint/widgets/brush_style_labels.dart';

export 'package:fpaint/widgets/brush_library.dart';
export 'package:fpaint/widgets/brush_stroke_preview.dart';
export 'package:fpaint/widgets/brush_style_labels.dart';
export 'package:fpaint/widgets/brush_style_swatch.dart';

/// A visual brush library: every [BrushStyle] shown as a live stroke preview,
/// grouped by [BrushStyleCategory] (the Procreate brush-library pattern).
class BrushStylePicker extends BasePicker<BrushStyle> {
  /// Creates a [BrushStylePicker].
  const BrushStylePicker({
    super.key,
    required super.title,
    required super.value,
    required super.onChanged,
  });

  @override
  BasePickerState<BrushStyle> createState() => _BrushStylePickerState();
}

/// The state for [BrushStylePicker].
class _BrushStylePickerState extends BasePickerState<BrushStyle> {
  @override
  BrushStyle clampValue(BrushStyle value) {
    return value; // No clamping needed for enums
  }

  @override
  Widget buildPickerWidget() {
    return BrushLibrary(value: currentValue, onChanged: updateValue);
  }

  @override
  String formatValue(BrushStyle value) {
    return brushStyleLabel(context.l10n, value);
  }
}

/// Shows the brush library in a bottom sheet.
///
/// The [context] parameter is the [BuildContext] used to show the sheet.
/// The [brushStyle] parameter is the currently selected brush style.
/// The [onChanged] parameter is called each time a tile is tapped; the sheet
/// stays open so styles can be compared, like Procreate's brush library.
void showBrushStylePicker(
  BuildContext context,
  BrushStyle brushStyle,
  void Function(BrushStyle) onChanged,
) {
  final AppLocalizations l10n = context.l10n;
  showPickerDialog(
    context: context,
    title: l10n.brushLibrary,
    titleIcon: const AppSvgIcon(icon: AppIcon.lineStyle),
    child: BrushStylePicker(
      title: l10n.brushStyle,
      value: brushStyle,
      onChanged: onChanged,
    ),
  );
}
