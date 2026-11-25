import 'dart:typed_data';

/// Packs variable-width bit fields into a byte buffer in LSB-first order.
class WebPBitWriter {
  static const int _bitsPerByte = 8;

  final List<int> _bytes = <int>[];
  int _currentByte = 0;
  int _usedBits = 0;

  /// Appends the lowest [numBits] bits of [value] to the stream.
  void writeBits(int value, int numBits) {
    int currentValue = value;
    int bitsRemaining = numBits;
    while (bitsRemaining > 0) {
      final int available = _bitsPerByte - _usedBits;
      final int bitsToWrite = bitsRemaining < available ? bitsRemaining : available;
      final int mask = (1 << bitsToWrite) - 1;
      _currentByte |= (currentValue & mask) << _usedBits;
      currentValue >>= bitsToWrite;
      bitsRemaining -= bitsToWrite;
      _usedBits += bitsToWrite;
      if (_usedBits == _bitsPerByte) {
        _bytes.add(_currentByte);
        _currentByte = 0;
        _usedBits = 0;
      }
    }
  }

  /// Writes any partially-filled byte to the buffer.
  void flush() {
    if (_usedBits > 0) {
      _bytes.add(_currentByte);
      _currentByte = 0;
      _usedBits = 0;
    }
  }

  /// Returns the accumulated bytes written so far.
  Uint8List getBytes() => Uint8List.fromList(_bytes);
}
