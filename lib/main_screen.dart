import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/panels/canvas_panel.dart';
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
      body: Row(
        children: [
          // Left side panels
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8),
              child: Material(
                elevation: 18,
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Column(
                  children: [
                    // Layers Panel
                    Expanded(
                      child: LayersPanel(
                        selectedLayerIndex: _selectedLayerIndex,
                        onSelectLayer: _selectLayer,
                        onAddLayer: _onAddLayer,
                        onFileOpen: _onFileOpen,
                        onRemoveLayer: _removeLayer,
                        onToggleViewLayer: _onToggleViewLayer,
                      ),
                    ),
                    // Tools Panel
                    Divider(
                      thickness: 8,
                      height: 16,
                      color: Colors.grey,
                    ),
                    Expanded(
                      child: ToolsPanel(
                        currentShapeType: _currentShapeType,
                        onShapeSelected: _onShapeSelected,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Canvas on the right
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: appModel.canvasSize.width,
                    height: appModel.canvasSize.height,
                    child: GestureDetector(
                      onPanStart: (details) =>
                          _handlePanStart(details.localPosition),
                      onPanUpdate: (details) =>
                          _handlePanUpdate(details.localPosition),
                      onPanEnd: _handlePanEnd,
                      child: CanvasPanel(appModel: paintModel),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Undo/Redo
      floatingActionButton: floatingActionButtons(paintModel),
    );
  }

  // Method to add a new layer
  void _onAddLayer() {
    final Layer newLayer = appModel.addLayerTop();
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

  Widget floatingActionButtons(AppModel paintModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.undo(),
          child: Icon(Icons.undo),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.redo(),
          child: Icon(Icons.redo),
        ),
        SizedBox(height: 8),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale += 0.10,
          child: Icon(Icons.zoom_in),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale = 1,
          child: Text(
            '${(paintModel.scale * 100).toInt()}%\n${paintModel.canvasSize.width.toInt()}\n${paintModel.canvasSize.height.toInt()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        FloatingActionButton(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
          onPressed: () => paintModel.scale -= 0.10,
          child: Icon(Icons.zoom_out),
        ),
      ],
    );
  }
}
