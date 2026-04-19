import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'painting_test_helpers.dart';

const String _testFrameSignature = '0123456789abcdef';
const String _testFramesDirectoryPath = '/tmp/frames';
const String _testTemporaryVideoOutputPath = '/tmp/unit_test_video.mp4.tmp';
const String _embeddedSignaturePrefix = 'prefix:';
const String _embeddedSignatureSuffix = ':suffix';
const String _temporaryDirectoryPrefix = 'painting_test_helpers_video_test_';

void main() {
  group('unit test video recorder assembly', () {
    test('builds deterministic ffmpeg arguments', () {
      final List<String> arguments = buildUnitTestVideoAssemblyArguments(
        framesDirectoryPath: _testFramesDirectoryPath,
        outputPath: _testTemporaryVideoOutputPath,
        frameSignature: _testFrameSignature,
      );

      expect(
        arguments,
        containsAllInOrder(<String>[
          '-map_metadata',
          '-1',
          '-map_chapters',
          '-1',
        ]),
      );
      expect(arguments, contains('creation_time=2000-01-01T00:00:00'));
      expect(arguments, contains('comment=frame_signature:$_testFrameSignature'));
      expect(arguments.last, _testTemporaryVideoOutputPath);
    });

    test('extracts embedded frame signatures from MP4 bytes', () {
      final Uint8List bytes = Uint8List.fromList(
        <int>[
          ..._embeddedSignaturePrefix.codeUnits,
          ...buildUnitTestVideoFrameSignatureComment(_testFrameSignature).codeUnits,
          ..._embeddedSignatureSuffix.codeUnits,
        ],
      );

      expect(extractUnitTestVideoFrameSignature(bytes), _testFrameSignature);
    });

    test('hashes frame bytes deterministically', () async {
      final Directory temporaryDirectory = await Directory.systemTemp.createTemp(
        _temporaryDirectoryPrefix,
      );
      addTearDown(() async {
        if (await temporaryDirectory.exists()) {
          await temporaryDirectory.delete(recursive: true);
        }
      });

      final File secondFrame = File('${temporaryDirectory.path}/frame_000002.png');
      final File firstFrame = File('${temporaryDirectory.path}/frame_000001.png');
      await secondFrame.writeAsBytes(<int>[1, 2, 3]);
      await firstFrame.writeAsBytes(<int>[4, 5, 6]);

      final String firstSignature = await computeUnitTestVideoFrameSignature(
        temporaryDirectory,
      );
      final String secondSignature = await computeUnitTestVideoFrameSignature(
        temporaryDirectory,
      );

      expect(firstSignature, secondSignature);

      await secondFrame.writeAsBytes(<int>[1, 2, 4]);
      final String changedSignature = await computeUnitTestVideoFrameSignature(
        temporaryDirectory,
      );

      expect(changedSignature, isNot(firstSignature));
    });
  });
}
