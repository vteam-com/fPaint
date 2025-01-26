import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

enum BrushStyle {
  solid,
  dash,
  // airbrush,
  // charcoal,
  // marker,
}

Widget brushStyleSelection(final AppModel appModel) {
  return DropdownButton<int>(
    value: appModel.brushStyle.index,
    items: BrushStyle.values.map<DropdownMenuItem<int>>((BrushStyle value) {
      return DropdownMenuItem<int>(
        value: value.index,
        child: SizedBox(
          width: 250,
          child: Text(value.name),
        ),
      );
    }).toList(),
    onChanged: (int? selectedBrush) {
      appModel.brushStyle = BrushStyle.values[selectedBrush!];
    },
  );
}

void showBrushStylePicker(
  final BuildContext context,
) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Select Line Style'),
        content: IntrinsicHeight(
          child: brushStyleSelection(AppModel.get(context)),
        ),
      );
    },
  );
}
