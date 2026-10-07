import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/main.dart';

void main() {
  test('platform file queue preserves arrival order', () {
    while (dequeueQueuedPlatformFile() != null) {
      // Clear any leftovers from earlier runs.
    }

    queuePlatformFileForProcessing('first.png');
    queuePlatformFileForProcessing('second.png');

    expect(dequeueQueuedPlatformFile(), 'first.png');
    expect(dequeueQueuedPlatformFile(), 'second.png');
    expect(dequeueQueuedPlatformFile(), isNull);
  });

  test('platform file queue ignores a path that is already waiting', () {
    while (dequeueQueuedPlatformFile() != null) {
      // Clear any leftovers from earlier runs.
    }

    // At launch iOS delivers the same file as fileOpened and as the pending file.
    queuePlatformFileForProcessing('opened.png');
    queuePlatformFileForProcessing('opened.png');

    expect(dequeueQueuedPlatformFile(), 'opened.png');
    expect(dequeueQueuedPlatformFile(), isNull);
  });
}
