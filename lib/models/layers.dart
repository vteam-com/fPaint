// Imports
import 'package:fpaint/models/shapes.dart';

// Exports
export 'package:fpaint/models/shapes.dart';

class PaintLayer {
  PaintLayer({required this.name});
  String name;
  List<Shape> shapes = [];
  bool isVisible = true;
}
