import 'package:flutter/material.dart';
import 'package:fpaint/l10n/app_localizations.dart';

Widget buildLocalizedTestApp({
  required final Widget home,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

Widget buildLocalizedScaffoldTestApp({
  required final Widget Function(BuildContext context) bodyBuilder,
  final MediaQueryData? mediaQueryData,
}) {
  return buildLocalizedTestApp(
    home: Scaffold(
      body: Builder(
        builder: (final BuildContext context) {
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
