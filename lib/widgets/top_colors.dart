import 'package:flutter/widgets.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/helpers/constants.dart';
import 'package:fpaint/helpers/image_helper.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/material_free.dart';
import 'package:fpaint/widgets/transparent_background.dart';

/// A widget that displays the top colors used in the application.
///
/// This widget takes a list of [ColorUsage] objects, which represent the
/// colors used in the application and their popularity. It then displays
/// these colors in a grid, sorted by hue and popularity. The user can
/// refresh the list of colors or select a color to trigger a callback.
///
/// The widget can be displayed in a minimal mode, which removes some
/// of the UI elements.
class TopColors extends StatefulWidget {
  /// Creates a [TopColors] widget.
  ///
  /// The [colorUsages] parameter specifies the list of [ColorUsage] objects to display.
  /// The [onRefresh] parameter specifies a callback that is called when the user refreshes the list of colors.
  /// The [onColorPicked] parameter specifies a callback that is called when the user selects a color.
  /// The [minimal] parameter specifies whether to display the widget in minimal mode.
  const TopColors({
    super.key,
    required this.colorUsages,
    required this.onRefresh,
    required this.onColorPicked,
    this.minimal = false,
    this.showHeader = true,
    this.autoRefreshOnIdle = false,
    this.refreshRevision = 0,
  });

  /// Whether the widget should refresh automatically after idle.
  final bool autoRefreshOnIdle;

  /// The list of [ColorUsage] objects to display.
  final List<ColorUsage> colorUsages;

  /// Whether to display the widget in minimal mode.
  final bool minimal;

  /// A callback that is called when the user selects a color.
  final void Function(Color) onColorPicked;

  /// A callback that is called when the user refreshes the list of colors.
  final VoidCallback onRefresh;

  /// Monotonic token that changes when canvas content affecting top colors changes.
  final int refreshRevision;

  /// Whether to display the title and refresh row.
  final bool showHeader;
  @override
  State<TopColors> createState() => _TopColorsState();
}

class _TopColorsState extends State<TopColors> {
  final Debouncer _refreshDebouncer = Debouncer();
  int _scheduledRefreshRevision = 0;
  @override
  void initState() {
    super.initState();
    _scheduleAutoRefreshIfNeeded();
  }

  @override
  void dispose() {
    _refreshDebouncer.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(final TopColors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.autoRefreshOnIdle != widget.autoRefreshOnIdle) {
      _scheduleAutoRefreshIfNeeded();
    }
  }

  @override
  Widget build(final BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ColorUsage> sortedColors = sortColorByHueAndPopularity();

    final List<Widget> colorPreviews = sortedColors.map((final ColorUsage colorUsed) {
      final List<String> components = getColorComponentsAsHex(colorUsed.color);
      final String alpha = components[0];
      final String red = components[1];
      final String green = components[AppMath.pair];
      final String blue = components[AppMath.triple];
      final String colorAsHex = '$red$green$blue\n$alpha';
      String tooltipText = '';
      if (colorUsed.percentage < 1) {
        tooltipText = l10n.colorUsage(colorUsed.toStringPercentage(AppStroke.thin.toInt()));
      }

      return ColorPreview(
        color: colorUsed.color,
        minimal: widget.minimal,
        text: colorAsHex,
        tooltipText: tooltipText,
        onPressed: () {
          widget.onColorPicked(colorUsed.color);
        },
      );
    }).toList();

    return Column(
      children: <Widget>[
        if (widget.showHeader)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (!widget.minimal) AppText(l10n.topColors(widget.colorUsages.length)),
              AppButtonIcon(
                icon: const AppSvgIcon(icon: AppIcon.refresh),
                onPressed: widget.onRefresh,
              ),
            ],
          ),
        IntrinsicHeight(
          child: transparentPaperContainer(
            Padding(
              padding: EdgeInsets.all(widget.minimal ? 0 : AppSpacing.small),
              child: Wrap(
                spacing: 1,
                runSpacing: 1,
                children: colorPreviews,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Sorts the `colorUsages` list by hue and popularity.
  ///
  /// The colors are first grouped by hue similarity (using a 15-degree threshold).
  /// Each hue group is then sorted by percentage (descending) and saturation (ascending).
  /// Finally, the hue groups are sorted by their total percentage usage (descending).
  ///
  /// The resulting list of `ColorUsage` objects is sorted by hue and popularity, with the most popular colors appearing first.
  List<ColorUsage> sortColorByHueAndPopularity() {
    final Map<int, List<ColorUsage>> groupedByHue = <int, List<ColorUsage>>{};

    // Group colors by hue similarity (using a 15-degree threshold)
    for (final ColorUsage usage in widget.colorUsages) {
      final double hue = HSVColor.fromColor(usage.color).hue;
      final int hueKey = (hue / 15).round() * 15; // Grouping by 15-degree steps

      groupedByHue.putIfAbsent(hueKey, () => <ColorUsage>[]);
      groupedByHue[hueKey]!.add(usage);
    }

    // Sort each hue group by percentage (descending), then by hue (ascending)
    for (final List<ColorUsage> group in groupedByHue.values) {
      group.sort((final ColorUsage a, final ColorUsage b) {
        final int percentageComparison = b.percentage.compareTo(a.percentage);
        if (percentageComparison != 0) {
          return percentageComparison;
        }
        final double saturationA = HSVColor.fromColor(a.color).saturation;
        final double saturationB = HSVColor.fromColor(b.color).saturation;
        return saturationB.compareTo(saturationA); // Secondary sort by saturation
      });
    }

    // Sort hue groups by total percentage usage (descending)
    final List<List<ColorUsage>> sortedGroups = groupedByHue.values.toList();
    sortedGroups.sort((final List<ColorUsage> a, final List<ColorUsage> b) {
      final double totalA = a.fold(
        0,
        (final double sum, final ColorUsage item) => sum + item.percentage,
      );
      final double totalB = b.fold(
        0,
        (final double sum, final ColorUsage item) => sum + item.percentage,
      );
      return totalB.compareTo(totalA);
    });

    // Flatten the sorted groups into a final sorted list
    return sortedGroups.expand((final List<ColorUsage> group) => group).toList();
  }

  /// Debounces a refresh so the top-colors list updates after canvas edits go idle.
  void _scheduleAutoRefreshIfNeeded() {
    if (!widget.autoRefreshOnIdle || widget.refreshRevision <= _scheduledRefreshRevision) {
      return;
    }

    final int refreshRevision = widget.refreshRevision;
    _refreshDebouncer.run(() {
      if (!mounted || refreshRevision < widget.refreshRevision) {
        return;
      }
      _scheduledRefreshRevision = refreshRevision;
      widget.onRefresh();
    });
  }
}
