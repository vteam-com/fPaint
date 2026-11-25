import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/brush_style.dart';
import 'package:fpaint/widgets/brush_stroke_preview.dart';
import 'package:fpaint/widgets/brush_style_labels.dart';
import 'package:fpaint/widgets/material_free.dart';

/// The compact inline control in the tools panel: the current style drawn as a
/// stroke plus its name. Tapping it opens the full [BrushLibrary].
class BrushStyleSwatch extends StatelessWidget {
  /// Creates a [BrushStyleSwatch].
  const BrushStyleSwatch({
    super.key,
    required this.value,
    required this.onTap,
  });

  /// Opens the brush library.
  final VoidCallback onTap;

  /// The style to preview.
  final BrushStyle value;

  @override
  Widget build(BuildContext context) {
    final String label = brushStyleLabel(context.l10n, value);
    return BrushPreviewTapTarget(
      key: Keys.toolBrushStyleSwatch,
      label: label,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: AppBrushLibrary.swatchWidth,
            height: AppBrushLibrary.swatchHeight,
            child: BrushStrokePreview(style: value, brushSize: AppBrushLibrary.swatchBrushSize),
          ),
          const SizedBox(width: AppSpacing.small),
          Flexible(
            child: AppText(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
