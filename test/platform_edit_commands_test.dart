import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native edit commands forward undo and redo to the app provider', () async {
    mainApp = MyApp();
    int counter = 0;

    mainApp.appProvider.undoProvider.executeAction(
      name: 'test-action',
      backward: () => counter--,
      forward: () => counter++,
    );

    expect(counter, 1);

    await handlePlatformEditMethodCall(const MethodCall('undo'));
    expect(counter, 0);

    await handlePlatformEditMethodCall(const MethodCall('redo'));
    expect(counter, 1);
  });
}
