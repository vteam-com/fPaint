import 'dart:typed_data';

import 'package:fpaint/files/webp_bit_writer.dart';
import 'package:fpaint/files/webp_encoder_shared.dart';
import 'package:fpaint/files/webp_huffman_codec.dart';
import 'package:fpaint/files/webp_transform_codec.dart';
import 'package:image/image.dart' as img;

/// Encodes image data into the VP8L lossless bitstream format.
class WebPVp8LEncoder {
  WebPVp8LEncoder() : _huffmanCodec = WebPHuffmanCodec(), _transformCodec = WebPTransformCodec(WebPHuffmanCodec());

  final WebPHuffmanCodec _huffmanCodec;
  final WebPTransformCodec _transformCodec;

  /// Encodes the [image] pixels into VP8L bytes with transforms and LZ77.
  Uint8List encode(img.Image image, int width, int height) {
    final img.OutputBuffer out = img.OutputBuffer();

    final bool hasAlpha = image.numChannels >= WebPEncodingConstants.rgbaChannelCount;
    final int header = (width - 1) | ((height - 1) << 14) | ((hasAlpha ? 1 : 0) << 28);
    out
      ..writeByte(WebPEncodingConstants.vp8lSignatureByte)
      ..writeByte(header & WebPEncodingConstants.byteMask)
      ..writeByte((header >> WebPEncodingConstants.byteShift1) & WebPEncodingConstants.byteMask)
      ..writeByte((header >> WebPEncodingConstants.byteShift2) & WebPEncodingConstants.byteMask)
      ..writeByte((header >> WebPEncodingConstants.byteShift3) & WebPEncodingConstants.byteMask);

    final int predBlockW = (width + WebPEncodingConstants.predBlockSize - 1) ~/ WebPEncodingConstants.predBlockSize;
    final int predBlockH = (height + WebPEncodingConstants.predBlockSize - 1) ~/ WebPEncodingConstants.predBlockSize;
    final int numPixels = width * height;
    final Uint8List g = Uint8List(numPixels);
    final Uint8List r = Uint8List(numPixels);
    final Uint8List b = Uint8List(numPixels);
    final Uint8List a = Uint8List(numPixels);

    int i = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel p = image.getPixel(x, y);
        g[i] = p.g.toInt().clamp(0, WebPEncodingConstants.maxChannelValue);
        r[i] = p.r.toInt().clamp(0, WebPEncodingConstants.maxChannelValue);
        b[i] = p.b.toInt().clamp(0, WebPEncodingConstants.maxChannelValue);
        a[i] = hasAlpha
            ? p.a.toInt().clamp(0, WebPEncodingConstants.maxChannelValue)
            : WebPEncodingConstants.maxChannelValue;
        i++;
      }
    }

    _transformCodec.applySubtractGreenTransform(r, g, b, numPixels);

    final List<int> predModes = _transformCodec.selectPredictorModes(
      r,
      g,
      b,
      width,
      height,
      predBlockW,
      predBlockH,
      WebPEncodingConstants.predBlockSize,
    );

    _transformCodec.applyPredictorTransform(
      r,
      g,
      b,
      a,
      width,
      height,
      predBlockW,
      WebPEncodingConstants.predBlockSize,
      predModes,
    );

    final WebPBitWriter bw = WebPBitWriter()
      ..writeBits(1, 1)
      ..writeBits(
        WebPEncodingConstants.transformTypeSubtractGreen,
        WebPEncodingConstants.transformTypeBits,
      )
      ..writeBits(1, 1)
      ..writeBits(0, WebPEncodingConstants.transformTypeBits)
      ..writeBits(
        WebPEncodingConstants.predSizeBits - WebPEncodingConstants.predSizeBitsOffset,
        WebPEncodingConstants.predSizeBitsWidth,
      );

    _transformCodec.writePredictorSubImage(bw, predBlockW, predBlockH, predModes);

    bw
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1);

    final _WebPTokenStream tokens = _tokenize(r, g, b, a, numPixels);

    final List<int> greenFreq = List<int>.filled(WebPEncodingConstants.greenAlphabetSize, 0);
    final List<int> redFreq = List<int>.filled(WebPEncodingConstants.colorAlphabetSize, 0);
    final List<int> blueFreq = List<int>.filled(WebPEncodingConstants.colorAlphabetSize, 0);
    final List<int> alphaFreq = List<int>.filled(WebPEncodingConstants.colorAlphabetSize, 0);
    final List<int> distFreq = List<int>.filled(WebPEncodingConstants.distAlphabetSize, 0);

    int litPtr = 0;
    int refPtr = 0;
    for (final bool isLit in tokens.tokenIsLit) {
      if (isLit) {
        final int idx = tokens.tokenLitIdx[litPtr++];
        greenFreq[g[idx]]++;
        redFreq[r[idx]]++;
        blueFreq[b[idx]]++;
        alphaFreq[a[idx]]++;
      } else {
        final int len = tokens.tokenLen[refPtr];
        final int dist = tokens.tokenDist[refPtr];
        refPtr++;
        greenFreq[_lengthSymbol(len)]++;
        final int planeCode = _distToPlaneCode(width, dist);
        distFreq[_prefixCode(planeCode)]++;
      }
    }

    final List<int> greenCl = _huffmanCodec.buildHuffmanCodeLengths(
      greenFreq,
      WebPEncodingConstants.greenAlphabetSize,
    );
    final List<int> redCl = _huffmanCodec.buildHuffmanCodeLengths(
      redFreq,
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> blueCl = _huffmanCodec.buildHuffmanCodeLengths(
      blueFreq,
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> alphaCl = _huffmanCodec.buildHuffmanCodeLengths(
      alphaFreq,
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> distCl = _huffmanCodec.buildHuffmanCodeLengths(
      distFreq,
      WebPEncodingConstants.distAlphabetSize,
    );

    _huffmanCodec.writeHuffmanCode(bw, WebPEncodingConstants.greenAlphabetSize, greenCl);
    _huffmanCodec.writeHuffmanCode(bw, WebPEncodingConstants.colorAlphabetSize, redCl);
    _huffmanCodec.writeHuffmanCode(bw, WebPEncodingConstants.colorAlphabetSize, blueCl);
    _huffmanCodec.writeHuffmanCode(bw, WebPEncodingConstants.colorAlphabetSize, alphaCl);
    _huffmanCodec.writeHuffmanCode(bw, WebPEncodingConstants.distAlphabetSize, distCl);

    final List<int> greenCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(greenCl),
      WebPEncodingConstants.greenAlphabetSize,
    );
    final List<int> redCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(redCl),
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> blueCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(blueCl),
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> alphaCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(alphaCl),
      WebPEncodingConstants.colorAlphabetSize,
    );
    final List<int> distCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(distCl),
      WebPEncodingConstants.distAlphabetSize,
    );

    litPtr = 0;
    refPtr = 0;
    for (final bool isLit in tokens.tokenIsLit) {
      if (isLit) {
        final int idx = tokens.tokenLitIdx[litPtr++];
        bw
          ..writeBits(greenCodes[g[idx]], greenCl[g[idx]])
          ..writeBits(redCodes[r[idx]], redCl[r[idx]])
          ..writeBits(blueCodes[b[idx]], blueCl[b[idx]])
          ..writeBits(alphaCodes[a[idx]], alphaCl[a[idx]]);
      } else {
        final int len = tokens.tokenLen[refPtr];
        final int dist = tokens.tokenDist[refPtr];
        refPtr++;

        final int lSym = _lengthSymbol(len);
        bw.writeBits(greenCodes[lSym], greenCl[lSym]);
        final (int lExtra, int lVal) = _lengthExtra(len);
        if (lExtra > 0) {
          bw.writeBits(lVal, lExtra);
        }

        final int planeCode = _distToPlaneCode(width, dist);
        final int dSym = _prefixCode(planeCode);
        bw.writeBits(distCodes[dSym], distCl[dSym]);
        final (int dExtra, int dVal) = _prefixExtra(planeCode);
        if (dExtra > 0) {
          bw.writeBits(dVal, dExtra);
        }
      }
    }

    bw.flush();
    out.writeBytes(bw.getBytes());
    return out.getBytes();
  }

  /// Tokenizes pixel data using hash-chain LZ77 back-reference matching.
  _WebPTokenStream _tokenize(
    Uint8List r,
    Uint8List g,
    Uint8List b,
    Uint8List a,
    int numPixels,
  ) {
    final List<bool> tokenIsLit = <bool>[];
    final List<int> tokenLitIdx = <int>[];
    final List<int> tokenLen = <int>[];
    final List<int> tokenDist = <int>[];

    final Map<int, List<int>> hashChain = <int, List<int>>{};

    void addToHash(int pos) {
      final int key =
          (g[pos] << WebPEncodingConstants.byteShift3) |
          (r[pos] << WebPEncodingConstants.byteShift2) |
          (b[pos] << WebPEncodingConstants.byteShift1) |
          a[pos];
      final List<int> list = hashChain.putIfAbsent(key, () => <int>[]);
      if (list.length >= WebPEncodingConstants.maxHashChainLength) {
        list.removeAt(0);
      }
      list.add(pos);
    }

    int j = 0;
    while (j < numPixels) {
      final int key =
          (g[j] << WebPEncodingConstants.byteShift3) |
          (r[j] << WebPEncodingConstants.byteShift2) |
          (b[j] << WebPEncodingConstants.byteShift1) |
          a[j];

      int bestLen = 0;
      int bestDist = 0;
      final List<int>? candidates = hashChain[key];
      if (j > 0 && candidates != null) {
        for (int ci = candidates.length - 1; ci >= 0; ci--) {
          final int c = candidates[ci];
          final int dist = j - c;
          if (dist > WebPEncodingConstants.maxVp8lBackRefDistance) {
            break;
          }

          int len = 1;
          while (len < WebPEncodingConstants.maxMatchLength &&
              j + len < numPixels &&
              g[j + len] == g[c + len] &&
              r[j + len] == r[c + len] &&
              b[j + len] == b[c + len] &&
              a[j + len] == a[c + len]) {
            len++;
          }
          if (len > bestLen || (len == bestLen && dist < bestDist)) {
            bestLen = len;
            bestDist = dist;
          }
        }
      }

      if (bestLen >= WebPEncodingConstants.minMatchLength) {
        tokenIsLit.add(false);
        tokenLen.add(bestLen);
        tokenDist.add(bestDist);
        for (int k = 0; k < bestLen; k++) {
          addToHash(j + k);
        }
        j += bestLen;
      } else {
        tokenIsLit.add(true);
        tokenLitIdx.add(j);
        addToHash(j);
        j++;
      }
    }

    return _WebPTokenStream(tokenIsLit, tokenLitIdx, tokenLen, tokenDist);
  }

  int _lengthSymbol(int length) {
    assert(length >= 1 && length <= WebPEncodingConstants.maxMatchLength);
    if (length <= WebPEncodingConstants.shortLengthThreshold) {
      return WebPEncodingConstants.shortLengthSymbolBase + length;
    }
    final int msb = _log2Floor(length - 1);
    final int half = (length - 1) >> (msb - 1) & 1;
    return WebPEncodingConstants.longLengthSymbolBase + WebPEncodingConstants.prefixBaseMultiplier * msb + half;
  }

  /// Returns the extra-bits count and value for a VP8L length prefix code.
  (int extraBits, int extraValue) _lengthExtra(int length) {
    if (length <= WebPEncodingConstants.shortLengthThreshold) {
      return (0, 0);
    }
    final int msb = _log2Floor(length - 1);
    final int half = (length - 1) >> (msb - 1) & 1;
    final int eb = msb - 1;
    final int base = (WebPEncodingConstants.prefixBaseMultiplier + half) << eb;
    return (eb, (length - 1) - base);
  }

  /// Converts a pixel distance to a VP8L plane code using the lookup table.
  int _distToPlaneCode(int width, int dist) {
    final int yoff = dist ~/ width;
    final int xoff = dist - yoff * width;
    if (xoff <= WebPEncodingConstants.planeLutWindow && yoff < WebPEncodingConstants.planeLutWindow) {
      return WebPEncodingConstants.planeLut[yoff * WebPEncodingConstants.planeLutCols +
              WebPEncodingConstants.planeLutWindow -
              xoff] +
          1;
    } else if (xoff > width - WebPEncodingConstants.planeLutWindow && yoff < WebPEncodingConstants.planeLutMaxYoff) {
      return WebPEncodingConstants.planeLut[(yoff + 1) * WebPEncodingConstants.planeLutCols +
              WebPEncodingConstants.planeLutWindow +
              width -
              xoff] +
          1;
    }
    return dist + WebPEncodingConstants.distancePlaneOffset;
  }

  int _prefixCode(int v) {
    final int val = v - 1;
    if (val < WebPEncodingConstants.prefixDirectCodes) {
      return val;
    }
    final int msb = _log2Floor(val);
    final int half = val >> (msb - 1) & 1;
    return WebPEncodingConstants.prefixBaseMultiplier * msb + half;
  }

  /// Returns the extra-bits count and value for a VP8L distance prefix code.
  (int extraBits, int extraValue) _prefixExtra(int v) {
    final int val = v - 1;
    if (val < WebPEncodingConstants.prefixDirectCodes) {
      return (0, 0);
    }
    final int msb = _log2Floor(val);
    final int half = val >> (msb - 1) & 1;
    final int eb = msb - 1;
    final int base = (WebPEncodingConstants.prefixBaseMultiplier + half) << eb;
    return (eb, val - base);
  }

  int _log2Floor(int v) {
    int log = 0;
    int remaining = v;
    while (remaining > 1) {
      remaining >>= 1;
      log++;
    }
    return log;
  }
}

class _WebPTokenStream {
  _WebPTokenStream(
    this.tokenIsLit,
    this.tokenLitIdx,
    this.tokenLen,
    this.tokenDist,
  );

  final List<bool> tokenIsLit;
  final List<int> tokenLitIdx;
  final List<int> tokenLen;
  final List<int> tokenDist;
}
