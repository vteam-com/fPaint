import 'dart:typed_data';

import 'package:fpaint/files/webp_bit_writer.dart';
import 'package:fpaint/files/webp_encoder_shared.dart';
import 'package:fpaint/files/webp_huffman_codec.dart';

/// Applies and writes VP8L spatial transforms (subtract-green, predictor).
class WebPTransformCodec {
  WebPTransformCodec(this._huffmanCodec);

  final WebPHuffmanCodec _huffmanCodec;

  /// Applies the subtract-green transform, subtracting green from red and blue.
  void applySubtractGreenTransform(
    Uint8List r,
    Uint8List g,
    Uint8List b,
    int numPixels,
  ) {
    for (int i = 0; i < numPixels; i++) {
      r[i] = (r[i] - g[i]) & WebPEncodingConstants.byteMask;
      b[i] = (b[i] - g[i]) & WebPEncodingConstants.byteMask;
    }
  }

  /// Selects the best predictor mode per block to minimise residual cost.
  List<int> selectPredictorModes(
    Uint8List r,
    Uint8List g,
    Uint8List b,
    int width,
    int height,
    int blockW,
    int blockH,
    int blockSize,
  ) {
    final List<int> candidates = <int>[
      WebPEncodingConstants.predictorModeLeft,
      WebPEncodingConstants.predictorModeTop,
      WebPEncodingConstants.predictorModeAverage,
      WebPEncodingConstants.predictorModeSelect,
    ];
    final List<int> modes = List<int>.filled(
      blockW * blockH,
      WebPEncodingConstants.predictorModeSelect,
    );

    for (int by = 0; by < blockH; by++) {
      for (int bx = 0; bx < blockW; bx++) {
        final int x0 = bx * blockSize;
        final int y0 = by * blockSize;
        final int x1 = (x0 + blockSize).clamp(0, width);
        final int y1 = (y0 + blockSize).clamp(0, height);

        int bestMode = WebPEncodingConstants.predictorModeSelect;
        int bestCost = WebPEncodingConstants.maxCostSentinel;

        for (final int m in candidates) {
          int cost = 0;
          for (int y = y0; y < y1; y++) {
            for (int x = x0; x < x1; x++) {
              final int idx = y * width + x;
              int pR;
              int pG;
              int pB;
              if (y == 0 && x == 0) {
                pR = 0;
                pG = 0;
                pB = 0;
              } else if (y == 0) {
                final int li = idx - 1;
                pR = r[li];
                pG = g[li];
                pB = b[li];
              } else if (x == 0) {
                final int ti = idx - width;
                pR = r[ti];
                pG = g[ti];
                pB = b[ti];
              } else {
                final int li = idx - 1;
                final int ti = idx - width;
                switch (m) {
                  case WebPEncodingConstants.predictorModeLeft:
                    pR = r[li];
                    pG = g[li];
                    pB = b[li];
                  case WebPEncodingConstants.predictorModeTop:
                    pR = r[ti];
                    pG = g[ti];
                    pB = b[ti];
                  case WebPEncodingConstants.predictorModeAverage:
                    pR = (r[li] + r[ti]) >> 1;
                    pG = (g[li] + g[ti]) >> 1;
                    pB = (b[li] + b[ti]) >> 1;
                  default:
                    final int tli = ti - 1;
                    final int sl = (r[li] - r[tli]).abs() + (g[li] - g[tli]).abs() + (b[li] - b[tli]).abs();
                    final int st = (r[ti] - r[tli]).abs() + (g[ti] - g[tli]).abs() + (b[ti] - b[tli]).abs();
                    if (sl <= st) {
                      pR = r[ti];
                      pG = g[ti];
                      pB = b[ti];
                    } else {
                      pR = r[li];
                      pG = g[li];
                      pB = b[li];
                    }
                }
              }

              final int dr = (r[idx] - pR) & WebPEncodingConstants.byteMask;
              final int dg = (g[idx] - pG) & WebPEncodingConstants.byteMask;
              final int db = (b[idx] - pB) & WebPEncodingConstants.byteMask;

              cost += dr < WebPEncodingConstants.signedWrapThreshold ? dr : WebPEncodingConstants.channelRange - dr;
              cost += dg < WebPEncodingConstants.signedWrapThreshold ? dg : WebPEncodingConstants.channelRange - dg;
              cost += db < WebPEncodingConstants.signedWrapThreshold ? db : WebPEncodingConstants.channelRange - db;
            }
          }
          if (cost < bestCost) {
            bestCost = cost;
            bestMode = m;
          }
        }
        modes[by * blockW + bx] = bestMode;
      }
    }

    return modes;
  }

  /// Applies the predictor transform in-place, replacing pixels with residuals.
  void applyPredictorTransform(
    Uint8List r,
    Uint8List g,
    Uint8List b,
    Uint8List a,
    int width,
    int height,
    int blockW,
    int blockSize,
    List<int> modes,
  ) {
    final Uint8List origR = Uint8List.fromList(r);
    final Uint8List origG = Uint8List.fromList(g);
    final Uint8List origB = Uint8List.fromList(b);
    final Uint8List origA = Uint8List.fromList(a);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int i = y * width + x;
        int pR;
        int pG;
        int pB;
        int pA;
        if (y == 0 && x == 0) {
          pA = WebPEncodingConstants.maxChannelValue;
          pR = 0;
          pG = 0;
          pB = 0;
        } else if (y == 0) {
          final int li = i - 1;
          pR = origR[li];
          pG = origG[li];
          pB = origB[li];
          pA = origA[li];
        } else if (x == 0) {
          final int ti = i - width;
          pR = origR[ti];
          pG = origG[ti];
          pB = origB[ti];
          pA = origA[ti];
        } else {
          final int li = i - 1;
          final int ti = i - width;
          final int shift = blockSize.bitLength - 1;
          final int mode = modes[(y >> shift) * blockW + (x >> shift)];
          switch (mode) {
            case WebPEncodingConstants.predictorModeLeft:
              pR = origR[li];
              pG = origG[li];
              pB = origB[li];
              pA = origA[li];
            case WebPEncodingConstants.predictorModeTop:
              pR = origR[ti];
              pG = origG[ti];
              pB = origB[ti];
              pA = origA[ti];
            case WebPEncodingConstants.predictorModeAverage:
              pR = (origR[li] + origR[ti]) >> 1;
              pG = (origG[li] + origG[ti]) >> 1;
              pB = (origB[li] + origB[ti]) >> 1;
              pA = (origA[li] + origA[ti]) >> 1;
            default:
              final int tli = ti - 1;
              final int sl =
                  (origR[li] - origR[tli]).abs() +
                  (origG[li] - origG[tli]).abs() +
                  (origB[li] - origB[tli]).abs() +
                  (origA[li] - origA[tli]).abs();
              final int st =
                  (origR[ti] - origR[tli]).abs() +
                  (origG[ti] - origG[tli]).abs() +
                  (origB[ti] - origB[tli]).abs() +
                  (origA[ti] - origA[tli]).abs();
              if (sl <= st) {
                pR = origR[ti];
                pG = origG[ti];
                pB = origB[ti];
                pA = origA[ti];
              } else {
                pR = origR[li];
                pG = origG[li];
                pB = origB[li];
                pA = origA[li];
              }
          }
        }

        r[i] = (origR[i] - pR) & WebPEncodingConstants.byteMask;
        g[i] = (origG[i] - pG) & WebPEncodingConstants.byteMask;
        b[i] = (origB[i] - pB) & WebPEncodingConstants.byteMask;
        a[i] = (origA[i] - pA) & WebPEncodingConstants.byteMask;
      }
    }
  }

  /// Writes the predictor sub-image (mode grid) into the VP8L bitstream.
  void writePredictorSubImage(
    WebPBitWriter bw,
    int blockW,
    int blockH,
    List<int> modes,
  ) {
    final int n = blockW * blockH;
    final List<int> greenFreq = List<int>.filled(WebPEncodingConstants.greenAlphabetSize, 0);
    for (final int m in modes) {
      greenFreq[m]++;
    }

    final List<int> greenCl = _huffmanCodec.buildHuffmanCodeLengths(
      greenFreq,
      WebPEncodingConstants.greenAlphabetSize,
    );
    final List<int> greenCodes = _huffmanCodec.canonicalCodes(
      Int32List.fromList(greenCl),
      WebPEncodingConstants.greenAlphabetSize,
    );

    bw.writeBits(0, 1);
    _huffmanCodec.writeHuffmanCode(
      bw,
      WebPEncodingConstants.greenAlphabetSize,
      greenCl,
    );

    bw
      ..writeBits(1, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(1, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(1, 1)
      ..writeBits(0, 1)
      ..writeBits(1, 1)
      ..writeBits(
        WebPEncodingConstants.maxChannelValue,
        WebPEncodingConstants.simpleSymbolEightBitWidth,
      )
      ..writeBits(1, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1)
      ..writeBits(0, 1);

    for (int i = 0; i < n; i++) {
      final int mode = modes[i];
      bw.writeBits(greenCodes[mode], greenCl[mode]);
    }
  }
}
