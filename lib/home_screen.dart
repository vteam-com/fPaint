import 'package:flutter/material.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'models/paint_model.dart';
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
  void _selectLayer(final int layerIndex) {
    setState(() {
      _selectedLayerIndex = layerIndex;
      Provider.of<PaintModel>(context, listen: false)
          .setActiveLayer(layerIndex);
    });
  }

  // Method to remove a layer
  void _removeLayer(final int layerIndex) {
    Provider.of<PaintModel>(context, listen: false).removeLayer(layerIndex);
    setState(() {
      if (_selectedLayerIndex >=
          Provider.of<PaintModel>(context, listen: false).layers.length) {
        _selectedLayerIndex =
            Provider.of<PaintModel>(context, listen: false).layers.length - 1;
      }
    });
  }

  void _onToggleViewLayer(final int layerIndex) {
    Provider.of<PaintModel>(context, listen: false)
        .toggleLayerVisibility(layerIndex);
    setState(() {});
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

  void _onShapeSelected(final ShapeType shape) {
    setState(() {
      _currentShapeType = shape;
    });
  }

  @override
  Widget build(final BuildContext context) {
    // Ensure that PaintModel is provided above this widget in the widget tree
    final PaintModel paintModel = Provider.of<PaintModel>(context);

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) =>
                _handlePanStart(details.localPosition - paintModel.offset),
            onPanUpdate: (details) =>
                _handlePanUpdate(details.localPosition - paintModel.offset),
            onPanEnd: _handlePanEnd,
            child: Painter(paintModel: paintModel),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              elevation: 8,
              child: ToolsPanel(
                currentShapeType: _currentShapeType,
                currentColor: _currentColor,
                onShapeSelected: _onShapeSelected,
                onColorPicker: _showColorPicker,
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: LayersPanel(
                selectedLayerIndex: _selectedLayerIndex,
                onSelectLayer: _selectLayer,
                onAddLayer: _addLayer,
                onRemoveLayer: _removeLayer,
                onToggleViewLayer: _onToggleViewLayer,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => paintModel.undo(),
            child: Icon(Icons.undo),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => paintModel.redo(),
            child: Icon(Icons.redo),
          ),
        ],
      ),
    );
  }
}
