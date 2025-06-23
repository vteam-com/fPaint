// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/assets_helper.dart';
import 'package:fpaint/files/xcf_reader.dart';

void main() {
  testWidgets('Simply Run the app', (final WidgetTester tester) async {
    try {
      final ByteData inputImageXcf = await loadBinaryFromAssets('assets/test/sample.xcf');

      // ignore: unused_local_variable
      final Uint8List bytes = inputImageXcf.buffer.asUint8List();
      // ignore: unused_local_variable
      final FileXcf fileXcf = FileXcf();

      // DISABLE TEST UNTIL XCF is complted
      // final xfcFile = await fileXcf.readXcf(bytes);

      // expect(xfcFile.signature, 'gimp xcf ');
      // expect(xfcFile.version, 'v011');
      // expect(xfcFile.width, 900);
      // expect(xfcFile.height, 500);
      // expect(xfcFile.baseTypeString, 'RGB');
      // expect(xfcFile.layers.length, 0);

      // for (var i = 0; i < xfcFile.layers.length; i++) {
      //   print('${i + 1}. ${xfcFile.layers[i]}');
      // }
    } catch (e) {
      print('ERROR ${e.toString()}');
    }
  });
}
