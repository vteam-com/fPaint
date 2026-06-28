import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/providers/fill_service.dart';
import 'package:fpaint/providers/wand_selection_manager.dart';

void main() {
  group('WandSelectionManager', () {
    test('starts idle with no pending request and no cache', () {
      final WandSelectionManager manager = WandSelectionManager();

      expect(manager.isInProgress, isFalse);
      expect(manager.hasPendingRequest, isFalse);
      expect(manager.cachedImageData(0), isNull);
    });

    test('queueRequest stores the request and bumps the version', () {
      final WandSelectionManager manager = WandSelectionManager();
      final int before = manager.requestVersion;

      manager.queueRequest(position: const Offset(4, 6), sampleAllLayers: true);

      expect(manager.hasPendingRequest, isTrue);
      expect(manager.requestVersion, before + 1);

      final WandSelectionRequest? request = manager.takePendingRequest();
      expect(request!.position, const Offset(4, 6));
      expect(request.sampleAllLayers, isTrue);
    });

    test('takePendingRequest returns the queued request once then null', () {
      final WandSelectionManager manager = WandSelectionManager();
      manager.queueRequest(position: const Offset(1, 2), sampleAllLayers: false);
      final int version = manager.requestVersion;

      final WandSelectionRequest? request = manager.takePendingRequest();

      expect(request, isNotNull);
      expect(request!.position, const Offset(1, 2));
      expect(request.sampleAllLayers, isFalse);
      expect(request.version, version);
      expect(manager.hasPendingRequest, isFalse);
      expect(manager.takePendingRequest(), isNull);
    });

    test('cancelPendingRequest clears the queue and invalidates in-flight results', () {
      final WandSelectionManager manager = WandSelectionManager();
      manager.queueRequest(position: const Offset(3, 3), sampleAllLayers: true);
      final int before = manager.requestVersion;

      manager.cancelPendingRequest();

      expect(manager.hasPendingRequest, isFalse);
      expect(manager.requestVersion, before + 1);
    });

    test('cache round-trips data only while the signature matches', () {
      final WandSelectionManager manager = WandSelectionManager();
      final Uint8List pixels = Uint8List.fromList(<int>[1, 2, 3, 4]);

      manager.storeCache(signature: 42, pixels: pixels, width: 1, height: 1);

      final FillImageData? hit = manager.cachedImageData(42);
      expect(hit, isNotNull);
      expect(hit!.pixels, same(pixels));
      expect(hit.width, 1);
      expect(hit.height, 1);

      expect(manager.cachedImageData(43), isNull);
    });

    test('reset clears both the queue and the cache', () {
      final WandSelectionManager manager = WandSelectionManager();
      manager.queueRequest(position: const Offset(5, 5), sampleAllLayers: false);
      manager.storeCache(
        signature: 7,
        pixels: Uint8List.fromList(<int>[0, 0, 0, 0]),
        width: 1,
        height: 1,
      );

      manager.reset();

      expect(manager.hasPendingRequest, isFalse);
      expect(manager.cachedImageData(7), isNull);
    });
  });
}
