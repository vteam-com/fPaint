/// TIFF 6.0 specification constants used by the custom encoder.
class TiffConstants {
  // -- Byte-order marks --------------------------------------------------
  /// Little-endian byte-order mark ('II').
  static const int byteOrderLE1 = 0x49; // 'I'
  static const int byteOrderLE2 = 0x49; // 'I'

  /// TIFF magic number (always 42).
  static const int magic = 42;

  // -- IFD value types ----------------------------------------------------
  /// IFD value type: unsigned 8-bit integer.
  static const int typeByte = 1;

  /// IFD value type: unsigned 16-bit integer.
  static const int typeShort = 3;

  /// IFD value type: unsigned 32-bit integer.
  static const int typeLong = 4;

  /// IFD value type: unsigned rational (two LONGs: numerator / denominator).
  static const int typeRational = 5;

  // -- Tag IDs ------------------------------------------------------------
  /// Tag 256 – ImageWidth.
  static const int tagImageWidth = 256;

  /// Tag 257 – ImageHeight.
  static const int tagImageHeight = 257;

  /// Tag 258 – BitsPerSample.
  static const int tagBitsPerSample = 258;

  /// Tag 259 – Compression (1 = none).
  static const int tagCompression = 259;

  /// Tag 262 – PhotometricInterpretation (2 = RGB).
  static const int tagPhotometricInterpretation = 262;

  /// Tag 266 – FillOrder.
  static const int tagFillOrder = 266;

  /// Tag 273 – StripOffsets.
  static const int tagStripOffsets = 273;

  /// Tag 274 – Orientation.
  static const int tagOrientation = 274;

  /// Tag 277 – SamplesPerPixel.
  static const int tagSamplesPerPixel = 277;

  /// Tag 278 – RowsPerStrip.
  static const int tagRowsPerStrip = 278;

  /// Tag 279 – StripByteCounts.
  static const int tagStripByteCounts = 279;

  /// Tag 282 – XResolution (horizontal DPI as RATIONAL).
  static const int tagXResolution = 282;

  /// Tag 283 – YResolution (vertical DPI as RATIONAL).
  static const int tagYResolution = 283;

  /// Tag 284 – PlanarConfiguration (1 = chunky / interleaved).
  static const int tagPlanarConfiguration = 284;

  /// Tag 285 – PageName (layer name in layered TIFF SubIFDs).
  static const int tagPageName = 285;

  /// Tag 286 – XPosition.
  static const int tagXPosition = 286;

  /// Tag 287 – YPosition.
  static const int tagYPosition = 287;

  /// Tag 296 – ResolutionUnit.
  static const int tagResolutionUnit = 296;

  /// Tag 297 – PageNumber (page index and total count, two SHORTs).
  static const int tagPageNumber = 297;

  /// Tag 305 – Software.
  static const int tagSoftware = 305;

  /// Tag 316 – HostComputer.
  static const int tagHostComputer = 316;

  /// Tag 317 – Predictor.
  static const int tagPredictor = 317;

  /// Tag 330 – SubIFD.
  static const int tagSubIfd = 330;

  /// Tag 338 – ExtraSamples.
  static const int tagExtraSamples = 338;

  /// Tag 339 – SampleFormat.
  static const int tagSampleFormat = 339;

  /// Private SketchBook tag for layer model metadata.
  static const int tagSketchBookLayerModel = 50784;

  /// Private SketchBook tag for layer flags.
  static const int tagSketchBookLayerFlags = 50787;

  /// Private SketchBook tag for layer-name bytes.
  static const int tagSketchBookLayerName = 50788;

  /// Private SketchBook tag for application version.
  static const int tagSketchBookVersion = 50790;

  // -- Fixed tag values ---------------------------------------------------
  /// Compression value: no compression.
  static const int compressionNone = 1;

  /// Compression value: LZW.
  static const int compressionLzw = 5;

  /// PhotometricInterpretation value: RGB.
  static const int photometricRgb = 2;

  /// FillOrder value: most-significant bit to least-significant bit.
  static const int fillOrderMsbToLsb = 1;

  /// PlanarConfiguration value: chunky (RGBARGBA…).
  static const int planarChunky = 1;

  /// Predictor value: horizontal differencing.
  static const int predictorHorizontalDifferencing = 2;

  /// ExtraSamples value: associated alpha.
  static const int extraSamplesAssociatedAlpha = 1;

  /// ExtraSamples value: unassociated (straight) alpha.
  static const int extraSamplesUnassociatedAlpha = 2;

  /// Orientation value: row 0 top, column 0 left.
  static const int orientationTopLeft = 1;

  /// Orientation value: row 0 bottom, column 0 left.
  static const int orientationBottomLeft = 4;

  /// Bits per channel for 8-bit images.
  static const int bitsPerChannel = 8;

  /// ResolutionUnit value: inch.
  static const int resolutionUnitInch = 2;

  /// SampleFormat value: unsigned integer channels.
  static const int sampleFormatUnsignedInteger = 1;

  /// Default DPI numerator for XResolution / YResolution.
  static const int defaultDpi = 72;

  /// Default DPI denominator for XResolution / YResolution.
  static const int dpiDenominator = 1;

  /// RGB channel count (3).
  static const int rgbChannelCount = 3;

  /// RGBA channel count (4).
  static const int rgbaChannelCount = 4;

  // -- Structural sizes ---------------------------------------------------
  /// Size of the TIFF header in bytes.
  static const int headerSize = 8;

  /// Size of a single IFD entry in bytes.
  static const int ifdEntrySize = 12;

  /// Size of the "next IFD offset" field in bytes.
  static const int nextIfdSize = 4;

  /// Size of the IFD entry-count field in bytes.
  static const int ifdCountSize = 2;

  /// Size of a single RATIONAL value in bytes (two uint32).
  static const int rationalSize = 8;

  /// Total size of resolution data: two RATIONAL values (XRes + YRes).
  static const int resolutionDataSize = 16;

  /// Width of a SHORT value in bits, used for packing PageNumber.
  static const int shortBitWidth = 16;

  /// Shared zero/default value used for TIFF offsets and flag payloads.
  static const int noValue = 0;

  /// Number of SHORT values in a PageNumber tag entry (page index + total).
  static const int pageNumberCount = 2;

  /// Number of SketchBook layer flag slots in tag 50787.
  static const int sketchBookLayerFlagsCount = 8;

  /// Number of IFD entries for a base RGB image (includes resolution tags).
  static const int ifdEntryCountRgb = 13;

  /// Number of IFD entries for a base RGBA image (includes ExtraSamples).
  static const int ifdEntryCountRgba = 14;

  /// Number of IFD entries for an RGB layer page
  /// (adds ImageDescription + NewSubfileType + PageName + PageNumber).
  static const int ifdEntryCountRgbLayer = 18;

  /// Number of IFD entries for an RGBA layer page.
  static const int ifdEntryCountRgbaLayer = 19;

  /// IFD value type: ASCII string.
  static const int typeAscii = 2;

  /// Tag 254 – NewSubfileType.
  static const int tagNewSubfileType = 254;

  /// Tag 270 – ImageDescription (stores the layer name).
  static const int tagImageDescription = 270;

  /// Tag 272 – Model.
  static const int tagModel = 272;

  /// NewSubfileType value: page of a multi-page image.
  static const int subfileTypePage = 2;

  /// NewSubfileType value: reduced-resolution image.
  static const int subfileTypeReducedResolution = 1;

  /// SketchBook preview name used for the root thumbnail SubIFD.
  static const String pageNameThumbnail = 'Thumbnail';

  /// SketchBook software marker written on the root layered TIFF image.
  static const String sketchBookSoftware = 'Alias MultiLayer TIFF V1.1';

  /// SketchBook application version marker written on the root layered TIFF.
  static const String sketchBookVersion = 'V1_Mac_SketchBook_8.7.1';

  /// SketchBook-style root model payload written on the root TIFF image.
  static const String sketchBookRootModelPayload =
      '003, 003, ffffffff, 001, 1, 000, 000, 000, 000, 000, 000, 000, 000, 000, 000';

  /// SketchBook-style layer model payload written on each layer SubIFD.
  static const String sketchBookLayerModelPayload = '1.000, 00000000, 1, 0, 1, 0, 161, 0, 0, 0, 00000';

  /// SketchBook-style layer flags payload written on each layer SubIFD.
  static const String sketchBookLayerFlagsPayload = '0, 0, 0, 0, 0, 0, 0, 0';

  /// Fixed-point denominator used by SketchBook for layer positions.
  static const int sketchBookPositionDenominator = 262144;

  /// Fallback prefix for imported TIFF layers without embedded names.
  static const String fallbackLayerNamePrefix = 'Layer';

  /// Separator between the fallback layer prefix and numeric suffix.
  static const String fallbackLayerNameSeparator = ' ';

  // -- Layer metadata JSON keys -------------------------------------------
  /// JSON key for the layer name in the ImageDescription payload.
  static const String metaKeyName = 'name';

  /// JSON key for the layer opacity (0.0–1.0) in the ImageDescription payload.
  static const String metaKeyOpacity = 'opacity';

  /// JSON key for the layer blend mode in the ImageDescription payload.
  static const String metaKeyBlendMode = 'blendMode';

  /// JSON key for layer visibility in the ImageDescription payload.
  static const String metaKeyVisible = 'visible';

  /// JSON key for layer edit lock in the ImageDescription payload.
  static const String metaKeyLocked = 'locked';

  /// Public `package:image` type string for ASCII TIFF values.
  static const String ifdValueTypeAscii = 'ascii';
}
