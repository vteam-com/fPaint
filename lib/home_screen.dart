import 'package:flutter/material.dart';
import 'package:fpaint/layers_panel.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'paint_model.dart';
import 'painter.dart';

class HomeScreen extends StatefulWidget {
  final TextEditingController controller = TextEditingController();

  HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  ShapeType _currentShapeType = ShapeType.pencil;
  Color _currentColor = Colors.black;
  Offset? _panStart;
  Shape? _currentShape;

  int _selectedLayerIndex = 0; // Track the selected layer

  // Method to add a new layer
  void _addLayer() {
    Provider.of<PaintModel>(context, listen: false).addLayer();
    setState(() {
      _selectedLayerIndex =
          Provider.of<PaintModel>(context, listen: false).layers.length - 1;
    });
  }

  // Method to select a layer
  void _selectLayer(int index) {
    setState(() {
      _selectedLayerIndex = index;
    });
  }

  // Method to remove a layer
  void _removeLayer(int index) {
    Provider.of<PaintModel>(context, listen: false).removeLayer(index);
    setState(() {
      if (_selectedLayerIndex >=
          Provider.of<PaintModel>(context, listen: false).layers.length) {
        _selectedLayerIndex =
            Provider.of<PaintModel>(context, listen: false).layers.length - 1;
      }
    });
  }

  void _handlePanStart(Offset position) {
    _panStart = position;
    if (_currentShapeType != ShapeType.pencil) {
      _currentShape =
          Shape(position, position, _currentShapeType, _currentColor);
      Provider.of<PaintModel>(context, listen: false)
          .addShape(shape: _currentShape);
    }
  }

  void _handlePanUpdate(Offset position) {
    if (_panStart != null && _currentShapeType != ShapeType.pencil) {
      Provider.of<PaintModel>(context, listen: false).updateLastShape(position);
    } else if (_panStart != null && _currentShapeType == ShapeType.pencil) {
      Provider.of<PaintModel>(context, listen: false).addShape(
        start: _panStart!,
        end: position,
        type: _currentShapeType,
        color: _currentColor,
      );
      _panStart = position;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _panStart = null;
    _currentShape = null;
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _currentColor,
              onColorChanged: (Color color) {
                setState(() {
                  _currentColor = color;
                });
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Paint'),
        actions: [
          IconButton(
            icon: Icon(Icons.color_lens),
            onPressed: _showColorPicker,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (details) => _handlePanStart(details.localPosition),
              onPanUpdate: (details) => _handlePanUpdate(details.localPosition),
              onPanEnd: _handlePanEnd,
              child: Painter(paintModel: Provider.of<PaintModel>(context)),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: LayersPanel(
                  selectedLayerIndex: _selectedLayerIndex,
                  onSelectLayer: _selectLayer,
                  onAddLayer: _addLayer,
                  onRemoveLayer: _removeLayer,
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () =>
                Provider.of<PaintModel>(context, listen: false).undo(),
            child: Icon(Icons.undo),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () =>
                Provider.of<PaintModel>(context, listen: false).redo(),
            child: Icon(Icons.redo),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Pencil
            IconButton(
              icon: Icon(Icons.edit_outlined),
              onPressed: () => setState(() {
                _currentShapeType = ShapeType.pencil;
              }),
              color:
                  _currentShapeType == ShapeType.pencil ? _currentColor : null,
            ),

            // Line
            IconButton(
              icon: Icon(Icons.line_axis),
              onPressed: () => setState(() {
                _currentShapeType = ShapeType.line;
              }),
              color:
                  _currentShapeType == ShapeType.pencil ? _currentColor : null,
            ),

            // Rectangle
            IconButton(
              icon: Icon(Icons.crop_square),
              onPressed: () => setState(() {
                _currentShapeType = ShapeType.rectangle;
              }),
              color: _currentShapeType == ShapeType.rectangle
                  ? _currentColor
                  : null,
            ),
            // Circle
            IconButton(
              icon: Icon(Icons.circle_outlined),
              onPressed: () => setState(() {
                _currentShapeType = ShapeType.circle;
              }),
              color:
                  _currentShapeType == ShapeType.circle ? _currentColor : null,
            ),
            IconButton(
              icon: Icon(Icons.color_lens),
              onPressed: _showColorPicker,
              color: _currentColor,
            ),
          ],
        ),
      ),
    );
  }
}
