import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/models/visible_model.dart';

class TestVisibleModel extends VisibleModel {
  // Concrete implementation for testing
}

void main() {
  group('VisibleModel', () {
    test('initial state should be invisible', () {
      final TestVisibleModel model = TestVisibleModel();
      expect(model.isVisible, false);
    });

    test('clear should set isVisible to false', () {
      final TestVisibleModel model = TestVisibleModel();
      model.isVisible = true;
      model.clear();
      expect(model.isVisible, false);
    });
  });
}
