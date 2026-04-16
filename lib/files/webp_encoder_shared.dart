import 'dart:typed_data';

/// Named constants used across the WebP lossless encoder.
class WebPEncodingConstants {
  const WebPEncodingConstants._();

  static const String riffContainerTag = 'RIFF';
  static const String webpContainerTag = 'WEBP';
  static const String vp8lChunkTag = 'VP8L';

  static const int rgbaChannelCount = 4;

  static const int vp8lSignatureByte = 0x2F;
  static const int byteMask = 0xFF;
  static const int byteShift1 = 8;
  static const int byteShift2 = 16;
  static const int byteShift3 = 24;

  static const int maxChannelValue = 255;
  static const int channelRange = 256;
  static const int signedWrapThreshold = 128;

  static const int transformTypeBits = 2;
  static const int transformTypeSubtractGreen = 2;
  static const int predSizeBitsOffset = 2;
  static const int predSizeBitsWidth = 3;

  static const int predictorModeLeft = 1;
  static const int predictorModeTop = 2;
  static const int predictorModeAverage = 7;
  static const int predictorModeSelect = 11;

  static const int maxVp8lBackRefDistance = 1048456;
  static const int minMatchLength = 3;
  static const int maxMatchLength = 4096;
  static const int maxHashChainLength = 64;

  static const int shortLengthThreshold = 4;
  static const int shortLengthSymbolBase = 255;
  static const int longLengthSymbolBase = 256;

  static const int prefixDirectCodes = 4;
  static const int prefixBaseMultiplier = 2;

  static const int planeLutCols = 16;
  static const int planeLutWindow = 8;
  static const int planeLutMaxYoff = 7;
  static const int distancePlaneOffset = 120;

  static const int greenAlphabetSize = 280;
  static const int colorAlphabetSize = 256;
  static const int distAlphabetSize = 40;

  static const int metaAlphabetSize = 19;
  static const int maxHuffmanCodeBits = 15;
  static const int maxMetaCodeBits = 7;

  static const int simpleCodeMaxSymbols = 2;
  static const int simpleSymbolEightBitWidth = 8;

  static const int huffmanNodeMultiplier = 2;
  static const int maxCostSentinel = 0x7FFFFFFF;

  static const int minNumClCodeLengths = 4;
  static const int numClCcBitWidth = 4;
  static const int clCodeBitWidth = 3;
  static const int maxClCodeIndex = 18;

  static const int rleRepeatPrev = 16;
  static const int rleRepeatZeroShort = 17;
  static const int rleRepeatZeroLong = 18;
  static const int rleRepeatPrevBits = 2;
  static const int rleRepeatZeroShortBits = 3;
  static const int rleRepeatZeroLongBits = 7;
  static const int rleRepeatPrevMin = 3;
  static const int rleRepeatPrevMax = 6;
  static const int rleRepeatZeroShortMin = 3;
  static const int rleRepeatZeroShortMax = 10;
  static const int rleRepeatZeroLongMin = 11;
  static const int rleRepeatZeroLongMax = 138;

  static const int predSizeBits = 5;
  static const int predBlockSize = 1 << predSizeBits;

  static const int rgbaBytesPerPixel = 4;

  static const List<int> codeLengthOrder = <int>[
    17,
    18,
    0,
    1,
    2,
    3,
    4,
    5,
    16,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
  ];

  // VP8L plane-to-code lookup table (128 entries, 8 rows × 16 cols).
  static const List<int> planeLut = <int>[
    //  yoffset=0 (xoffset 8..1, then 0..-7 which are unused=255)
    96,
    73,
    55,
    39,
    23,
    13,
    5,
    1,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    //  yoffset=1
    101,
    78,
    58,
    42,
    26,
    16,
    8,
    2,
    0,
    3,
    9,
    17,
    27,
    43,
    59,
    79,
    //  yoffset=2
    102,
    86,
    62,
    46,
    32,
    20,
    10,
    6,
    4,
    7,
    11,
    21,
    33,
    47,
    63,
    87,
    //  yoffset=3
    105,
    90,
    70,
    52,
    37,
    28,
    18,
    14,
    12,
    15,
    19,
    29,
    38,
    53,
    71,
    91,
    //  yoffset=4
    110,
    99,
    82,
    66,
    48,
    35,
    30,
    24,
    22,
    25,
    31,
    36,
    49,
    67,
    83,
    100,
    //  yoffset=5
    115,
    108,
    94,
    76,
    64,
    50,
    44,
    40,
    34,
    41,
    45,
    51,
    65,
    77,
    95,
    109,
    //  yoffset=6
    118,
    113,
    103,
    92,
    80,
    68,
    60,
    56,
    54,
    57,
    61,
    69,
    81,
    93,
    104,
    114,
    //  yoffset=7
    119,
    116,
    111,
    106,
    97,
    88,
    84,
    74,
    72,
    75,
    85,
    89,
    98,
    107,
    112,
    117,
  ];
}

/// Converts a four-character ASCII tag into its byte representation.
Uint8List webPTag(String s) {
  final Uint8List bytes = Uint8List(s.length);
  for (int i = 0; i < s.length; i++) {
    bytes[i] = s.codeUnitAt(i);
  }
  return bytes;
}
