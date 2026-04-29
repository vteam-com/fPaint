import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpaint/files/webp_bit_writer.dart';
import 'package:fpaint/files/webp_huffman_codec.dart';

void main() {
  group('WebPHuffmanCodec', () {
    late WebPHuffmanCodec codec;

    setUp(() {
      codec = WebPHuffmanCodec();
    });

    test('buildHuffmanCodeLengths with all-zero frequencies', () {
      // Edge case: no symbols used => syms.isEmpty
      final List<int> freq = List<int>.filled(256, 0);
      final List<int> cl = codec.buildHuffmanCodeLengths(freq, 256);
      expect(cl.length, 256);
      // Should set cl[0] = 1 as fallback
      expect(cl[0], 1);
    });

    test('buildHuffmanCodeLengths with single symbol', () {
      // Edge case: exactly one symbol
      final List<int> freq = List<int>.filled(256, 0);
      freq[42] = 10;
      final List<int> cl = codec.buildHuffmanCodeLengths(freq, 256);
      expect(cl[42], 1);
    });

    test('buildHuffmanCodeLengths with multiple symbols', () {
      final List<int> freq = List<int>.filled(256, 0);
      freq[0] = 100;
      freq[1] = 50;
      freq[2] = 25;
      final List<int> cl = codec.buildHuffmanCodeLengths(freq, 256);
      expect(cl[0], greaterThan(0));
      expect(cl[1], greaterThan(0));
      expect(cl[2], greaterThan(0));
    });

    test('writeHuffmanCode with all-zero code lengths', () {
      final WebPBitWriter bw = WebPBitWriter();
      final List<int> cl = List<int>.filled(256, 0);
      codec.writeHuffmanCode(bw, 256, cl);
      expect(bw.getBytes(), isA<Uint8List>());
    });

    test('writeHuffmanCode with single used symbol at index 0', () {
      final WebPBitWriter bw = WebPBitWriter();
      final List<int> cl = List<int>.filled(256, 0);
      cl[0] = 1;
      codec.writeHuffmanCode(bw, 256, cl);
      expect(bw.getBytes(), isA<Uint8List>());
    });

    test('writeHuffmanCode with single used symbol > 1', () {
      final WebPBitWriter bw = WebPBitWriter();
      final List<int> cl = List<int>.filled(256, 0);
      cl[100] = 1;
      codec.writeHuffmanCode(bw, 256, cl);
      expect(bw.getBytes(), isA<Uint8List>());
    });

    test('writeHuffmanCode with two used symbols', () {
      final WebPBitWriter bw = WebPBitWriter();
      final List<int> cl = List<int>.filled(256, 0);
      cl[10] = 1;
      cl[20] = 2;
      codec.writeHuffmanCode(bw, 256, cl);
      expect(bw.getBytes(), isA<Uint8List>());
    });
  });
}
