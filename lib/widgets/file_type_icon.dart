import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';

/// Fraction of the icon width available inside the sheet outline, which spans
/// x 4.2..19.2 of the 24-unit icon grid less its stroke. The label is confined
/// to this box so it never spills across the sheet's edges.
const double _sheetBodyWidthFraction = 0.46;

/// Fraction of the icon height between the label band's bottom and the icon
/// bottom, clearing the sheet's stroked lower edge.
const double _labelBandBottomFraction = 0.24;

/// Height of the label band, as a fraction of the icon height. Sized to the
/// sheet's lower body so the label clears the folded corner above it.
const double _labelBandHeightFraction = 0.3;

/// Nominal font size of the extension label, as a fraction of the icon height.
const double _labelFontFraction = 0.26;

/// Line height of the extension label, so it sits tight within its band.
const double _labelLineHeight = 1.0;

/// The icon's full width as a fraction of itself, used to split the margin
/// left over beside the sheet body into equal left and right gutters.
const double _fullWidthFraction = 1.0;

/// A paper-sheet icon badged with a file-type extension, e.g. a sheet marked
/// `PNG`.
///
/// Used wherever a row names a file format, so formats are told apart at a
/// glance instead of every row repeating one generic icon.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({
    super.key,
    required this.extension,
    this.color,
    this.size,
  });

  /// Colour of both the sheet and the label; defaults to white.
  final Color? color;

  /// Extension shown on the sheet, e.g. `PNG`. Rendered upper-case.
  final String extension;

  /// Height and width of the icon; defaults to [AppLayout.iconSize].
  final double? size;

  @override
  Widget build(BuildContext context) {
    final double resolvedSize = size ?? AppLayout.iconSize;
    final Color resolvedColor = color ?? AppColors.white;

    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AppSvgIcon(
            icon: AppIcon.fileSheet,
            color: resolvedColor,
            size: resolvedSize,
          ),
          Positioned(
            left: resolvedSize * (_fullWidthFraction - _sheetBodyWidthFraction) / AppMath.pair,
            width: resolvedSize * _sheetBodyWidthFraction,
            height: resolvedSize * _labelBandHeightFraction,
            bottom: resolvedSize * _labelBandBottomFraction,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  extension.toUpperCase(),
                  maxLines: AppMath.one,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.label.copyWith(
                    color: resolvedColor,
                    fontSize: resolvedSize * _labelFontFraction,
                    fontWeight: FontWeight.bold,
                    height: _labelLineHeight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
