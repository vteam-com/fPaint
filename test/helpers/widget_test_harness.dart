import 'package:fpaint/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Widget buildLocalizedTestApp({
  required Widget home,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Widget buildLocalizedScaffoldTestApp({
  required Widget Function(BuildContext context) bodyBuilder,
  MediaQueryData? mediaQueryData,
}) {
  return buildLocalizedTestApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          final Widget body = bodyBuilder(context);
          if (mediaQueryData == null) {
            return body;
          }
          return MediaQuery(
            data: mediaQueryData,
            child: body,
          );
        },
      ),
    ),
  );
}
