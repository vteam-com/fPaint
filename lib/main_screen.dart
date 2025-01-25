import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpaint/files/file_ora.dart';
import 'package:fpaint/panels/canvas_panel.dart';
import 'package:fpaint/panels/layers_panel.dart';
import 'package:fpaint/panels/tools_panel.dart';

import 'models/app_model.dart';

class MainScreen extends StatefulWidget {
  MainScreen({super.key});
  final TextEditingController controller = TextEditingController();

  @override
  MainScreenState createState() => MainScreenState();
}

/// The [MainScreenState] class represents the state management for the main screen of
/// a paint application. It handles user interactions such as drawing, shape selection,
/// layer management, undo/redo operations, and file handling.
///
/// This class maintains state variables including:
/// - [_currentShapeType]: Current tool selected (e.g., draw, erase).
/// - [_panStart]: The starting position of a pan gesture.
/// - [_selectedLayerIndex]: Index of the currently selected layer in the layers panel.
/// - [_currentShape]: The current shape being drawn or edited.
class MainScreenState extends State<MainScreen> {
  /// Tracks the type of tool currently selected by the user.
  Tools _currentShapeType = Tools.draw;

  /// Stores the starting position of a pan gesture for drawing operations.
  Offset? _panStart;
  UserAction? _currentShape;

  /// Maintains the index of the currently active or selected layer in the layers panel.
  int _selectedLayerIndex = 0; // Track the selected layer

  @override
  Widget build(final BuildContext context) {
    // Ensure that AppModel is provided above this widget in the widget tree and listening
    final AppModel appModel = AppModel.get(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.grey,
      body: Row(
        children: [
          // Left side panels
          sidePanel(),
          // Canvas on the right
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: appModel.width,
                    height: appModel.height,
                    child: GestureDetector(
                      onScaleStart: (final ScaleStartDetails details) {
                        if (details.pointerCount == 1 && _panStart == null) {
                          _handlePanStart(
                            details.localFocalPoint / appModel.scale,
                          );
                        } else {
                          appModel.scale = appModel.scale;
                        }
                      },
                      onScaleUpdate: (final ScaleUpdateDetails details) {
                        appModel.scale = appModel.scale * details.scale;

                        if (_panStart != null && details.pointerCount == 1) {
                          _handlePanUpdate(
                            details.localFocalPoint / appModel.scale,
                          );
                        }
                      },
                      onScaleEnd: (ScaleEndDetails details) {
                        if (details.pointerCount == 0) {
                          // Reset pan start after scaling ends
                          _panStart = null;
                        }
                      },
                      child: CanvasPanel(appModel: appModel),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // Undo/Redo
      floatingActionButton: floatingActionButtons(appModel),
    );
  }

  Widget sidePanel() {
    return Container(
      width: 400,
      padding: const EdgeInsets.only(top: 8.0, bottom: 8),
      child: Material(
        elevation: 18,
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        clipBehavior: Clip.none,
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
    );
  }

  // Method to add a new layer
  void _onAddLayer() {
    final AppModel appModel = AppModel.get(context);
    final Layer newLayer = appModel.addLayerTop();
    setState(() {
      _selectedLayerIndex = appModel.layers.getLayerIndex(newLayer);
    });
  }

  void _onFileOpen() async {
    final AppModel appModel = AppModel.get(context);

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
      AppModel.get(context).setActiveLayer(layerIndex);
    });
  }

  // Method to remove a layer
  void _removeLayer(final int layerIndex) {
    final AppModel appModel = AppModel.get(context);

    appModel.removeLayer(layerIndex);
    setState(() {
      if (_selectedLayerIndex >= appModel.layers.length) {
        _selectedLayerIndex = appModel.layers.length - 1;
      }
    });
  }

  void _onToggleViewLayer(final int layerIndex) {
    AppModel.get(context).toggleLayerVisibility(layerIndex);
    setState(() {});
  }

  void _handlePanStart(Offset position) {
    final AppModel appModel = AppModel.get(context);

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

      appModel.addShape(shape: _currentShape);
    }
  }

  void _handlePanUpdate(Offset position) {
    final AppModel appModel = AppModel.get(context);

    if (_panStart != null) {
      if (_currentShapeType == Tools.eraser) {
        // Eraser implementation
        appModel.addShape(
          start: _panStart!,
          end: position,
          type: _currentShapeType,
          colorStroke: Colors.transparent,
          colorFill: Colors.transparent,
        );
        _panStart = position;
      } else if (_currentShapeType == Tools.draw) {
        // Existing pencil logic
        appModel.addShape(
          start: _panStart!,
          end: position,
          type: _currentShapeType,
          colorFill: appModel.colorForFill,
          colorStroke: appModel.colorForStroke,
        );
        _panStart = position;
      } else {
        // Existing shape logic
        appModel.updateLastShape(position);
      }
    }
  }

  /// Handles the selection of a shape type by the user.
  ///
  /// When the user selects a shape type, this method updates the `_currentShapeType`
  /// property to the selected shape. This allows the application to render the
  /// appropriate shape based on the user's selection.
  void _onShapeSelected(final Tools shape) {
    setState(() {
      _currentShapeType = shape;
    });
  }

  /// Builds a column of floating action buttons for the paint application,
  /// including buttons for undo, redo, zoom in, zoom out,
  ///  and a button that displays the current zoom level and canvas size.
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
