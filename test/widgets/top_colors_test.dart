import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/helpers/color_helper.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/app_icon.dart';
import 'package:fpaint/widgets/color_preview.dart';
import 'package:fpaint/widgets/top_colors.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/widget_test_harness.dart';

const Color _red = Color(0xFFFF0000);
const Color _paleRed = Color(0xFFFF8080);
const Color _blue = Color(0xFF0000FF);
const Color _green = Color(0xFF00FF00);
const double _redShare = 0.2;
const double _paleRedShare = 0.2;
const double _blueShare = 0.5;
const double _greenShare = 0.1;
const String _headerText = 'Top 4 colors';

void main() {
  List<ColorUsage> buildUsages() {
    return <ColorUsage>[
      ColorUsage(_red, _redShare),
      ColorUsage(_green, _greenShare),
      ColorUsage(_blue, _blueShare),
      ColorUsage(_paleRed, _paleRedShare),
    ];
  }

  testWidgets('header refresh button fires onRefresh and colors sort by hue-group popularity', (
    WidgetTester tester,
  ) async {
    int refreshCount = 0;
    final List<Color> picked = <Color>[];

    await tester.pumpWidget(
      buildLocalizedScaffoldTestApp(
        bodyBuilder: (BuildContext _) => SingleChildScrollView(
          child: TopColors(
            colorUsages: buildUsages(),
            onRefresh: () => refreshCount++,
            onColorPicked: picked.add,
          ),
        ),
      ),
    );

    expect(find.text(_headerText), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate((Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.refresh),
    );
    expect(refreshCount, 1);

    // Red + pale red share a hue group whose total (0.4) trails blue (0.5),
    // and the green group (0.1) comes last.
    final List<Color> order = tester
        .widgetList<ColorPreview>(find.byType(ColorPreview))
        .map((ColorPreview preview) => preview.color)
        .toList();
    expect(order.first, _blue);
    expect(order.last, _green);

    await tester.tap(find.byType(ColorPreview).first);
    expect(picked, <Color>[_blue]);
  });

  testWidgets('minimal mode hides the header title but keeps the refresh button', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildLocalizedScaffoldTestApp(
        bodyBuilder: (BuildContext _) => SingleChildScrollView(
          child: TopColors(
            colorUsages: buildUsages(),
            onRefresh: () {},
            onColorPicked: (Color _) {},
            minimal: true,
          ),
        ),
      ),
    );

    expect(find.text(_headerText), findsNothing);
    expect(
      find.byWidgetPredicate((Widget widget) => widget is AppSvgIcon && widget.icon == AppIcon.refresh),
      findsOneWidget,
    );
  });
}
