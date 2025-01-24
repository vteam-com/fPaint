import 'package:flutter/material.dart';
import 'package:fpaint/models/app_model.dart';

enum BrushStyle {
  solid,
  dash,
  // airbrush,
  // charcoal,
  // marker,
}

Widget brushSelection(final AppModel appModel) {
  return DropdownButton<int>(
    value: appModel.brush.index,
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
      appModel.brush = BrushStyle.values[selectedBrush!];
    },
  );
}
