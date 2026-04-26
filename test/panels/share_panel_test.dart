import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/panels/side_panel/share_panel.dart';

void main() {
  group('textAction', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('returns a Text widget', () {
      final Widget widget = textAction('image.PNG', l10n);
      expect(widget, isA<Text>());
    });

    test('text contains the file name', () {
      final Text widget = textAction('image.PNG', l10n) as Text;
      expect(widget.data, contains('image.PNG'));
    });

    test('text contains the file name for JPG', () {
      final Text widget = textAction('image.JPG', l10n) as Text;
      expect(widget.data, contains('image.JPG'));
    });

    test('text contains the file name for ORA', () {
      final Text widget = textAction('image.ORA', l10n) as Text;
      expect(widget.data, contains('image.ORA'));
    });
  });
}
