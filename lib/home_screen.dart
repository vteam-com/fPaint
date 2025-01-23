import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

import 'models/app_model.dart';
import 'my_canvas.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});
  final TextEditingController controller = TextEditingController();

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  ShapeType _currentShapeType = ShapeType.pencil;
  Color _currentColor = Colors.black;
  Offset? _panStart;
  Shape? _currentShape;
  late AppModel appModel = Provider.of<AppModel>(context, listen: false);

  int _selectedLayerIndex = 0; // Track the selected layer

  // Method to add a new layer
  void _onAddLayer() {
    final PaintLayer newLayer = appModel.addLayer();
    setState(() {
      _selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
    });
  }

  Future<Uint8List> _capturePainterToImageBytes(BuildContext context) async {
    final AppModel model = Provider.of<AppModel>(context, listen: false);
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Draw the custom painter on the canvas
    final MyCanvasPainter painter = MyCanvasPainter(model);

    painter.paint(canvas, model.canvasSize);

    // End the recording and get the picture
    final Picture picture = recorder.endRecording();

    // Convert the picture to an image
    final image = await picture.toImage(
      model.canvasSize.width.toInt(),
      model.canvasSize.height.toInt(),
    );

    // Convert the image to byte data (e.g., PNG)
    final ByteData? byteData = await image.toByteData(
      format: ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  void _onShare() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard != null) {
      final image = await _capturePainterToImageBytes(context);
      final item = DataWriterItem(suggestedName: 'fPaint.png');
      item.add(Formats.png(image));
      await clipboard.write([item]);
    } else {
      //
    }
  }

  // Method to select a layer
  void _selectLayer(final int layerIndex) {
    setState(() {
      _selectedLayerIndex = layerIndex;
      Provider.of<AppModel>(context, listen: false).setActiveLayer(layerIndex);
    });
  }

  // Method to remove a layer
  void _removeLayer(final int layerIndex) {
    Provider.of<AppModel>(context, listen: false).removeLayer(layerIndex);
    setState(() {
      if (_selectedLayerIndex >=
          Provider.of<AppModel>(context, listen: false).layers.length) {
        _selectedLayerIndex =
            Provider.of<AppModel>(context, listen: false).layers.length - 1;
      }
    });
  }

  void _onToggleViewLayer(final int layerIndex) {
    Provider.of<AppModel>(context, listen: false)
        .toggleLayerVisibility(layerIndex);
    setState(() {});
  }

  void _handlePanStart(Offset position) {
    _panStart = position;
    if (_currentShapeType != ShapeType.pencil) {
      _currentShape =
          Shape(position, position, _currentShapeType, _currentColor);
      Provider.of<AppModel>(context, listen: false)
          .addShape(shape: _currentShape);
    }
  }

  void _handlePanUpdate(Offset position) {
    if (_panStart != null && _currentShapeType != ShapeType.pencil) {
      Provider.of<AppModel>(context, listen: false).updateLastShape(position);
    } else if (_panStart != null && _currentShapeType == ShapeType.pencil) {
      Provider.of<AppModel>(context, listen: false).addShape(
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
    final AppModel paintModel = Provider.of<AppModel>(context);

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
            child: MyCanvas(paintModel: paintModel),
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
                onAddLayer: _onAddLayer,
                onShare: _onShare,
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
