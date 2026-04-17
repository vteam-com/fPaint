/// A code-length symbol with optional extra-bits payload for RLE encoding.
class WebPClSymbol {
  WebPClSymbol(this.symbol, this.extraBits, this.extraValue);
  final int symbol;
  final int extraBits;
  final int extraValue;
}
