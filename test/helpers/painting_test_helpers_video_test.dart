import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'painting_test_helpers.dart';

const String _testFrameSignature = '0123456789abcdef';

/// A 64-bit signature at or above 2^63, which `int.tryParse` cannot hold.
const String _highBitFrameSignature = '89d9d37da9e6cf5f';
const String _testUnsignedVideoPath = '/tmp/unit_test_video.unsigned.mp4';
const String _testSignedVideoPath = '/tmp/unit_test_video.tmp.mp4';
const String _testVideoPath = '/tmp/unit_test_video.mp4';
const String _testPipePath = '/tmp/frames.rgba';
const String _embeddedSignaturePrefix = 'prefix:';
const String _embeddedSignatureSuffix = ':suffix';
const int _testFrameWidth = 1600;
const int _testFrameHeight = 1200;

/// A frame whose length is not a multiple of eight, to cover the byte tail.
final Uint8List _testFrame = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);

void main() {
  group('unit test video recorder assembly', () {
    test('streams raw RGBA frames from a named pipe into a deterministic encode', () {
      final List<String> arguments = buildUnitTestVideoEncodeArguments(
        width: _testFrameWidth,
        height: _testFrameHeight,
        inputPath: _testPipePath,
        outputPath: _testUnsignedVideoPath,
      );

      expect(arguments, containsAllInOrder(<String>['-f', 'rawvideo', '-pix_fmt', 'rgba']));
      expect(arguments, containsAllInOrder(<String>['-s', '${_testFrameWidth}x$_testFrameHeight']));
      expect(arguments, containsAllInOrder(<String>['-i', _testPipePath]));
      expect(arguments, containsAllInOrder(<String>['-threads', '1']));
      expect(arguments.last, _testUnsignedVideoPath);
    });

    test('stamps the signature without re-encoding', () {
      final List<String> arguments = buildUnitTestVideoSignArguments(
        inputPath: _testUnsignedVideoPath,
        outputPath: _testSignedVideoPath,
        frameSignature: _testFrameSignature,
      );

      expect(arguments, containsAllInOrder(<String>['-i', _testUnsignedVideoPath]));
      expect(arguments, containsAllInOrder(<String>['-map_metadata', '-1', '-map_chapters', '-1']));
      expect(arguments, containsAllInOrder(<String>['-c', 'copy']));
      expect(arguments, contains('creation_time=2000-01-01T00:00:00'));
      expect(arguments, contains('comment=frame_signature:$_testFrameSignature'));
      expect(arguments.last, _testSignedVideoPath);
    });

    test('derives temporary output paths beside the video', () {
      expect(buildUnitTestTemporaryVideoOutputPath(_testVideoPath), _testSignedVideoPath);
      expect(buildUnitTestTemporaryVideoOutputPath(_testVideoPath, suffix: 'unsigned'), _testUnsignedVideoPath);
      expect(buildUnitTestTemporaryVideoOutputPath('/tmp/video'), '/tmp/video.tmp');
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
      expect(extractUnitTestVideoFrameSignature(Uint8List(0)), isNull);
    });

    test('accepts signatures with the top bit set', () {
      final Uint8List bytes = Uint8List.fromList(
        buildUnitTestVideoFrameSignatureComment(_highBitFrameSignature).codeUnits,
      );

      expect(extractUnitTestVideoFrameSignature(bytes), _highBitFrameSignature);
    });

    test('hashes frame pixels deterministically and order-sensitively', () {
      String signatureOf(List<Uint8List> frames) {
        final UnitTestVideoFrameSignature signature = UnitTestVideoFrameSignature();
        frames.forEach(signature.addFrame);
        return signature.hex;
      }

      final Uint8List changedFrame = Uint8List.fromList(_testFrame)..[_testFrame.length - 1] ^= 1;
      final String original = signatureOf(<Uint8List>[_testFrame, changedFrame]);

      expect(original, hasLength(_testFrameSignature.length));
      expect(signatureOf(<Uint8List>[_testFrame, changedFrame]), original);
      expect(signatureOf(<Uint8List>[changedFrame, _testFrame]), isNot(original));
      expect(signatureOf(<Uint8List>[_testFrame, _testFrame]), isNot(original));
    });
  });
}
