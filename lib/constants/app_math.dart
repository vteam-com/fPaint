// ignore: fcheck_magic_numbers

/// Shared geometry and math helpers for repeated factors.
class AppMath {
  /// Offset for red channel in RGBA pixel data.
  static const int rgbChannelRed = 0;

  /// Offset for green channel in RGBA pixel data.
  static const int rgbChannelGreen = 1;

  /// Offset for blue channel in RGBA pixel data.
  static const int rgbChannelBlue = 2;

  /// Offset for alpha channel in RGBA pixel data.
  static const int rgbChannelAlpha = 3;

  static const double degrees60 = 60.0;
  static const double degrees120 = 120.0;
  static const double degrees180 = 180.0;
  static const double degrees240 = 240.0;
  static const double degrees300 = 300.0;
  static const int zero = 0;
  static const int one = 1;
  static const int two = 2;
  static const int four = 4;
  static const int six = 6;
  static const int eight = 8;
  static const int pair = 2;
  static const int triple = 3;
  static const int bytesPerPixel = 4;
  static const int baseTen = 10;
  static const int hexRadix = 16;
  static const int hexPad = 2;
  static const double smallPercentage = 0.1;
  static const double degreesPerHalfTurn = 180.0;
  static const double degreesPerFullTurn = 360.0;
  static const double percentScale = 100.0;
  static const double tinyPercentage = 0.01;

  /// Approximation of π used for radian/degree conversions.
  static const double pi = 3.14159;

  /// Angle increment for rotation snap haptic feedback.
  static const double rotationSnapInterval = 45.0;

  /// Scale percentage increment for scale snap haptic feedback.
  static const double scaleSnapInterval = 25.0;
}
