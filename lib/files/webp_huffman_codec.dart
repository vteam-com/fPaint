import 'dart:typed_data';

import 'package:fpaint/files/webp_bit_writer.dart';
import 'package:fpaint/files/webp_encoder_shared.dart';

/// A code-length symbol with optional extra-bits payload for RLE encoding.
class _WebPClSymbol {
  _WebPClSymbol(this.symbol, this.extraBits, this.extraValue);
  final int symbol;
  final int extraBits;
  final int extraValue;
}

/// Builds, encodes, and writes Huffman codes for the VP8L bitstream.
class WebPHuffmanCodec {
  /// Builds canonical Huffman code lengths from symbol frequencies.
  List<int> buildHuffmanCodeLengths(
    List<int> freq,
    int alphabetSize, {
    int maxBits = WebPEncodingConstants.maxHuffmanCodeBits,
  }) {
    final List<int> cl = List<int>.filled(alphabetSize, 0);

    final List<int> syms = <int>[];
    for (int k = 0; k < alphabetSize; k++) {
      if (freq[k] > 0) {
        syms.add(k);
      }
    }

    if (syms.isEmpty) {
      cl[0] = 1;
      return cl;
    }
    if (syms.length == 1) {
      cl[syms[0]] = 1;
      return cl;
    }

    final int maxNodes = WebPEncodingConstants.huffmanNodeMultiplier * syms.length;
    final List<int> nodeFreq = List<int>.filled(maxNodes, 0);
    final List<int> nodeLeft = List<int>.filled(maxNodes, -1);
    final List<int> nodeRight = List<int>.filled(maxNodes, -1);

    for (int countMin = 1; ; countMin *= WebPEncodingConstants.huffmanNodeMultiplier) {
      for (int k = 0; k < syms.length; k++) {
        nodeFreq[k] = freq[syms[k]];
        if (nodeFreq[k] < countMin) {
          nodeFreq[k] = countMin;
        }
      }
      int nextNode = syms.length;

      final List<int> pq = List<int>.generate(syms.length, (int k) => k)
        ..sort((int x, int y) => nodeFreq[x].compareTo(nodeFreq[y]));

      while (pq.length > 1) {
        final int x = pq.removeAt(0);
        final int y = pq.removeAt(0);
        final int id = nextNode++;
        nodeFreq[id] = nodeFreq[x] + nodeFreq[y];
        nodeLeft[id] = x;
        nodeRight[id] = y;
        int pos = 0;
        while (pos < pq.length && nodeFreq[pq[pos]] <= nodeFreq[id]) {
          pos++;
        }
        pq.insert(pos, id);
      }

      final List<int> stackNodes = <int>[pq[0]];
      final List<int> stackDepths = <int>[0];
      int currentMaxBits = 0;

      while (stackNodes.isNotEmpty) {
        final int nodeId = stackNodes.removeLast();
        final int depth = stackDepths.removeLast();
        if (nodeLeft[nodeId] == -1) {
          cl[syms[nodeId]] = depth;
          if (depth > currentMaxBits) {
            currentMaxBits = depth;
          }
        } else {
          stackNodes
            ..add(nodeLeft[nodeId])
            ..add(nodeRight[nodeId]);
          stackDepths
            ..add(depth + 1)
            ..add(depth + 1);
        }
      }

      if (currentMaxBits <= maxBits) {
        break;
      }
    }

    return cl;
  }

  /// Serializes a Huffman code table into the VP8L bitstream.
  void writeHuffmanCode(
    WebPBitWriter bw,
    int alphabetSize,
    List<int> codeLengths,
  ) {
    final List<int> used = <int>[];
    for (int k = 0; k < alphabetSize; k++) {
      if (codeLengths[k] > 0) {
        used.add(k);
      }
    }

    if (used.length <= WebPEncodingConstants.simpleCodeMaxSymbols &&
        (used.isEmpty || used.last <= WebPEncodingConstants.maxChannelValue)) {
      bw.writeBits(1, 1);
      if (used.isEmpty) {
        bw
          ..writeBits(0, 1)
          ..writeBits(0, 1)
          ..writeBits(0, 1);
        return;
      }

      bw.writeBits(used.length - 1, 1);
      final int sym0 = used[0];
      if (sym0 <= 1) {
        bw
          ..writeBits(0, 1)
          ..writeBits(sym0, 1);
      } else {
        bw
          ..writeBits(1, 1)
          ..writeBits(sym0, WebPEncodingConstants.simpleSymbolEightBitWidth);
      }

      if (used.length == WebPEncodingConstants.simpleCodeMaxSymbols) {
        bw.writeBits(used[1], WebPEncodingConstants.simpleSymbolEightBitWidth);
      } else if (used.length == 1) {
        codeLengths[sym0] = 0;
      }
      return;
    }

    final List<_WebPClSymbol> clSymbols = buildRleSequence(codeLengths, alphabetSize);

    final List<int> clFreq = List<int>.filled(WebPEncodingConstants.metaAlphabetSize, 0);
    for (final _WebPClSymbol s in clSymbols) {
      clFreq[s.symbol]++;
    }

    final List<int> clCl = buildHuffmanCodeLengths(
      clFreq,
      WebPEncodingConstants.metaAlphabetSize,
      maxBits: WebPEncodingConstants.maxMetaCodeBits,
    );
    final List<int> clCodes = canonicalCodes(
      Int32List.fromList(clCl),
      WebPEncodingConstants.metaAlphabetSize,
    );

    int numClCl = WebPEncodingConstants.minNumClCodeLengths;
    for (int k = WebPEncodingConstants.maxClCodeIndex; k >= WebPEncodingConstants.minNumClCodeLengths; k--) {
      if (clCl[WebPEncodingConstants.codeLengthOrder[k]] != 0) {
        numClCl = k + 1;
        break;
      }
    }

    bw
      ..writeBits(0, 1)
      ..writeBits(
        numClCl - WebPEncodingConstants.minNumClCodeLengths,
        WebPEncodingConstants.numClCcBitWidth,
      );

    for (int k = 0; k < numClCl; k++) {
      bw.writeBits(
        clCl[WebPEncodingConstants.codeLengthOrder[k]],
        WebPEncodingConstants.clCodeBitWidth,
      );
    }

    bw.writeBits(0, 1);

    for (final _WebPClSymbol s in clSymbols) {
      bw.writeBits(clCodes[s.symbol], clCl[s.symbol]);
      if (s.extraBits > 0) {
        bw.writeBits(s.extraValue, s.extraBits);
      }
    }
  }

  /// Compresses [codeLengths] into an RLE symbol sequence per the VP8L spec.
  // ignore: library_private_types_in_public_api
  List<_WebPClSymbol> buildRleSequence(List<int> codeLengths, int alphabetSize) {
    final List<_WebPClSymbol> result = <_WebPClSymbol>[];
    int i = 0;
    while (i < alphabetSize) {
      final int cl = codeLengths[i];
      if (cl == 0) {
        int count = 0;
        while (i + count < alphabetSize && codeLengths[i + count] == 0) {
          count++;
        }
        int rem = count;
        while (rem > 0) {
          if (rem >= WebPEncodingConstants.rleRepeatZeroLongMin) {
            final int n = rem.clamp(
              WebPEncodingConstants.rleRepeatZeroLongMin,
              WebPEncodingConstants.rleRepeatZeroLongMax,
            );
            result.add(
              _WebPClSymbol(
                WebPEncodingConstants.rleRepeatZeroLong,
                WebPEncodingConstants.rleRepeatZeroLongBits,
                n - WebPEncodingConstants.rleRepeatZeroLongMin,
              ),
            );
            rem -= n;
          } else if (rem >= WebPEncodingConstants.rleRepeatZeroShortMin) {
            final int n = rem.clamp(
              WebPEncodingConstants.rleRepeatZeroShortMin,
              WebPEncodingConstants.rleRepeatZeroShortMax,
            );
            result.add(
              _WebPClSymbol(
                WebPEncodingConstants.rleRepeatZeroShort,
                WebPEncodingConstants.rleRepeatZeroShortBits,
                n - WebPEncodingConstants.rleRepeatZeroShortMin,
              ),
            );
            rem -= n;
          } else {
            result.add(_WebPClSymbol(0, 0, 0));
            rem--;
          }
        }
        i += count;
      } else {
        result.add(_WebPClSymbol(cl, 0, 0));
        i++;
        while (i < alphabetSize && codeLengths[i] == cl) {
          int count = 0;
          while (i + count < alphabetSize &&
              codeLengths[i + count] == cl &&
              count < WebPEncodingConstants.rleRepeatPrevMax) {
            count++;
          }
          if (count >= WebPEncodingConstants.rleRepeatPrevMin) {
            result.add(
              _WebPClSymbol(
                WebPEncodingConstants.rleRepeatPrev,
                WebPEncodingConstants.rleRepeatPrevBits,
                count - WebPEncodingConstants.rleRepeatPrevMin,
              ),
            );
            i += count;
          } else {
            for (int k = 0; k < count; k++) {
              result.add(_WebPClSymbol(cl, 0, 0));
            }
            i += count;
          }
        }
      }
    }
    return result;
  }

  /// Generates canonical Huffman codes from [codeLengths] with LSB-first bit order.
  List<int> canonicalCodes(Int32List codeLengths, int numSymbols) {
    final List<int> codes = List<int>.filled(numSymbols, 0);
    int maxLen = 0;
    for (int k = 0; k < numSymbols; k++) {
      if (codeLengths[k] > maxLen) {
        maxLen = codeLengths[k];
      }
    }
    if (maxLen == 0) {
      return codes;
    }

    final List<int> blCount = List<int>.filled(maxLen + 1, 0);
    for (int k = 0; k < numSymbols; k++) {
      if (codeLengths[k] > 0) {
        blCount[codeLengths[k]]++;
      }
    }
    blCount[0] = 0;

    final List<int> nextCode = List<int>.filled(maxLen + 1, 0);
    int code = 0;
    for (int bits = 1; bits <= maxLen; bits++) {
      code = (code + blCount[bits - 1]) << 1;
      nextCode[bits] = code;
    }

    for (int k = 0; k < numSymbols; k++) {
      final int len = codeLengths[k];
      if (len > 0) {
        codes[k] = reverseBits(nextCode[len], len);
        nextCode[len]++;
      }
    }

    return codes;
  }

  /// Reverses the lowest [numBits] bits of [value].
  int reverseBits(int value, int numBits) {
    int currentValue = value;
    int result = 0;
    for (int k = 0; k < numBits; k++) {
      result = (result << 1) | (currentValue & 1);
      currentValue >>= 1;
    }
    return result;
  }
}
