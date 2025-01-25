import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/canvas.dart';
import 'package:fpaint/files/ora.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';
import 'package:provider/provider.dart';
import 'models/app_model.dart';

class MainScreen extends StatefulWidget {
  MainScreen({super.key});
  final TextEditingController controller = TextEditingController();

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  Tools _currentShapeType = Tools.draw;
  Offset? _panStart;
  UserAction? _currentShape;
  late AppModel appModel = Provider.of<AppModel>(context, listen: false);

  int _selectedLayerIndex = 0; // Track the selected layer

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
            child: MyCanvas(appModel: paintModel),
          ),

          // Panel for Layers
          Positioned(
            top: 8,
            left: 8,
            child: Card(
              elevation: 8,
              child: LayersPanel(
                selectedLayerIndex: _selectedLayerIndex,
                onSelectLayer: _selectLayer,
                onAddLayer: _onAddLayer,
                onFileOpen: _onFileOpen,
                onRemoveLayer: _removeLayer,
                onToggleViewLayer: _onToggleViewLayer,
              ),
            ),
          ),

          // Panel for tools
          Positioned(
            top: 8,
            right: 8,
            child: Card(
              elevation: 8,
              child: ToolsPanel(
                currentShapeType: _currentShapeType,
                onShapeSelected: _onShapeSelected,
              ),
            ),
          ),
        ],
      ),

      // Undo/Redo
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade700,
            onPressed: () => paintModel.undo(),
            child: Icon(Icons.undo),
          ),
          SizedBox(height: 8),
          FloatingActionButton(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade700,
            onPressed: () => paintModel.redo(),
            child: Icon(Icons.redo),
          ),
        ],
      ),
    );
  }

  // Method to add a new layer
  void _onAddLayer() {
    final PaintLayer newLayer = appModel.addLayerTop();
    setState(() {
      _selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
    });
  }

  void _onFileOpen() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        appModel.layers.clear();

        if (kIsWeb) {
          await readOraFileFromBytes(appModel, result.files.single.bytes!);
        } else {
          await readOraFile(appModel, result.files.single.path!);
        }
        setState(() {
          // Refresh UI after importing
        });
      }
    } catch (e) {
      // Handle any errors that occur during file picking/loading
      print('Error opening file: $e');
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
    if (_currentShapeType != Tools.draw) {
      _currentShape = UserAction(
        start: position,
        end: position,
        type: _currentShapeType,
        colorOutline: appModel.colorForStroke,
        colorFill: appModel.colorForFill,
        brushSize: appModel.lineWeight,
        brushStyle: appModel.brush,
      );

      Provider.of<AppModel>(context, listen: false)
          .addShape(shape: _currentShape);
    }
  }

  void _handlePanUpdate(Offset position) {
    if (_panStart != null) {
      if (_currentShapeType == Tools.eraser) {
        // Eraser implementation
        Provider.of<AppModel>(context, listen: false).addShape(
          start: _panStart!,
          end: position,
          type: _currentShapeType,
          colorStroke: Colors.transparent, // Or your canvas background color
          colorFill: Colors.transparent,
        );
        _panStart = position;
      } else if (_currentShapeType == Tools.draw) {
        // Existing pencil logic
        Provider.of<AppModel>(context, listen: false).addShape(
          start: _panStart!,
          end: position,
          type: _currentShapeType,
          colorFill: appModel.colorForFill,
          colorStroke: appModel.colorForStroke,
        );
        _panStart = position;
      } else {
        // Existing shape logic
        Provider.of<AppModel>(context, listen: false).updateLastShape(position);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _panStart = null;
    _currentShape = null;
  }

  void _onShapeSelected(final Tools shape) {
    setState(() {
      _currentShapeType = shape;
    });
  }
}
