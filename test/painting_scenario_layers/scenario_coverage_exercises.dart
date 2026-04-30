part of '../painting_scenario_test.dart';

// ---------------------------------------------------------------------------
// Coverage exercise constants
// ---------------------------------------------------------------------------
const String _coverageRenamedLayerName = 'Renamed Layer';
const String _coverageFloatingUndoActionName = 'floating-buttons-undo';
const double _coverageSelectionMargin = 50.0;
const double _coverageBrushSize = 6.0;
const double _coverageEraserBrushSize = 10.0;

/// Taps the floating undo button [count] times, pumping generously after
/// each so the tap is visible in the recorded video and async backward
/// callbacks (e.g. canvas rotations with toImage) complete fully.
Future<void> _undoTimes(
  final WidgetTester tester,
  final int count,
) async {
  for (int i = 0; i < count; i++) {
    await tapByKey(tester, Keys.floatActionUndo);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }
}

/// Exercises various UI code paths to increase test coverage.
Future<void> exerciseCoverageScenarios(
  final PaintingScenarioSession session,
) async {
  // Clear stale undo/redo entries from scene painting so they don't
  // interfere with coverage exercises that use undo.
  final BuildContext initContext = session.tester.element(find.byType(MainView));
  AppProvider.of(initContext, listen: false).undoProvider.clear();

  await _exerciseLayerOperations(session);
  await _exerciseKeyboardShortcuts(session);
  await _exerciseToolSwitching(session);
  await _exerciseTextEditor(session);
  await _exerciseSelectionToolPanel(session);
  await _exerciseSelectionFlipRotate(session);
  await _exerciseSelectionCropAndDuplicate(session);
  await _exerciseMenuDialogs(session);
  await _exerciseCanvasTransforms(session);
  await _exerciseSelectionOperations(session);
  await _exerciseLayerBlendMode(session);
  await _exerciseSidePanelButtons(session);
  await _exerciseCanvasSettingsDialog(session);
  await _exerciseMoreToolSwitching(session);
  await _exerciseShapeDrawing(session);
  await _exerciseSidePanelToggle(session);
  await _exerciseLayerRenameDialog(session);
  await _exerciseMenuNavigations(session);
  await _exerciseShellModeToggle(session);
  await _exerciseToolColorPickers(session);
  await _exerciseLayerAddDelete(session);
  await _exerciseFloatingButtons(session);
  await _exerciseSelectionViaGesture(session);
  await _exerciseLayerTapInteractions(session);
  await _exerciseToolPanelButtons(session);
  await _exerciseLayerPopupMenuActions(session);
  await _exerciseSelectionToolPanelButtons(session);
  await _exerciseSelectionAdvanced(session);
  await _exerciseCanvasResizeLockAspectRatio(session);
  await _exerciseCanvasSettingsValidation(session);
  await _exerciseToleranceAndTopColors(session);
  await _exerciseBrushStylePicker(session);
  await _exerciseSettingsPage(session);

  // Dismiss any open menus/dialogs and ensure the main view is visible.
  while (Navigator.of(session.tester.element(find.byType(MainView))).canPop()) {
    Navigator.of(session.tester.element(find.byType(MainView))).pop();
    await session.tester.pump();
    await session.tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }
  // Switch to selector tool for a clean final state.
  await tapByKey(session.tester, Keys.toolSelector);
  await session.tester.pump();

  debugPrint('✅ Coverage exercise scenarios completed');
}

// ---------------------------------------------------------------------------
// Layer operations
// ---------------------------------------------------------------------------

/// Exercises layer add, rename, visibility toggle, delete.
Future<void> _exerciseLayerOperations(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  // Add a temporary layer.
  await PaintingLayerHelpers.addNewLayer(tester, _coverageRenamedLayerName);
  final int layerCountAfterAdd = layersProvider.length;
  expect(layerCountAfterAdd, greaterThan(_expectedLayerCountAfterScene));

  // Rename the layer.
  await PaintingLayerHelpers.renameLayer(tester, 'Temp Renamed');

  // Toggle visibility.
  layersProvider.selectedLayer.isVisible = false;
  layersProvider.update();
  await tester.pump();
  expect(layersProvider.selectedLayer.isVisible, isFalse);

  layersProvider.selectedLayer.isVisible = true;
  layersProvider.update();
  await tester.pump();

  // Remove the temporary layer.
  await PaintingLayerHelpers.removeLayer(
    tester,
    layersProvider.selectedLayerIndex,
  );

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Keyboard shortcuts
// ---------------------------------------------------------------------------

/// Exercises keyboard shortcuts: select-all, escape, delete, tab, undo.
Future<void> _exerciseKeyboardShortcuts(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Select all (Cmd+A).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  // Duplicate selection (Cmd+D).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
  await tester.pump();

  // Cancel with Escape.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();

  // Select all again and erase (Delete key).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  await tester.sendKeyEvent(LogicalKeyboardKey.delete);
  await tester.pump();

  // Undo the erase (Cmd+Z).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  // Toggle shell mode with Tab.
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();

  // Escape to clear any lingering state.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();

  // Redo (Cmd+Shift+Z).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  // Undo the erase that was redone above.
  await _undoTimes(tester, 1);

  // Help shortcut (Ctrl+/).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyEvent(LogicalKeyboardKey.slash);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();

  // Dismiss help dialog.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Clean up any lingering state from Cmd+D image placement.
  final BuildContext kbContext = tester.element(find.byType(MainView));
  final AppProvider kbAppProvider = AppProvider.of(kbContext, listen: false);
  kbAppProvider.cancelImagePlacement();
  kbAppProvider.selectorModel.clear();
  kbAppProvider.undoProvider.clear();
  kbAppProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Tool switching
// ---------------------------------------------------------------------------

/// Exercises switching between pencil, eraser, and brush tools with strokes.
Future<void> _exerciseToolSwitching(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Switch to pencil.
  await tapByTooltip(tester, l10n.toolPencil);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.pencil);

  // Draw a small pencil stroke.
  await drawFreehandStrokeWithHumanGestures(
    tester,
    points: <Offset>[
      session.canvasCenter + const Offset(-20, -20),
      session.canvasCenter + const Offset(20, -20),
    ],
    brushSize: _coverageBrushSize,
    brushColor: const Color.fromARGB(255, 0, 0, 0),
  );

  // Switch to eraser.
  await tapByTooltip(tester, l10n.toolEraser);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.eraser);

  // Draw a small eraser stroke.
  await drawFreehandStrokeWithHumanGestures(
    tester,
    points: <Offset>[
      session.canvasCenter + const Offset(-20, -20),
      session.canvasCenter + const Offset(20, -20),
    ],
    action: ActionType.eraser,
    brushSize: _coverageEraserBrushSize,
  );

  // Switch to brush.
  await tapByTooltip(tester, l10n.toolBrush);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.brush);

  // Undo the eraser and pencil strokes.
  // Each freehand stroke with 2 points creates 2 actions (initial + move),
  // so 2 strokes = 4 undos needed.
  await _undoTimes(tester, 4);

  // Switch back to selector.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Text editor
// ---------------------------------------------------------------------------

/// Exercises the text editor dialog by triggering it via selectedTextObject.
Future<void> _exerciseTextEditor(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final AppLocalizations l10n = context.l10n;

  // Remember the original stack length so we only remove test-added text
  // actions and preserve the Signature layer's original text.
  final int stackLengthBefore = appProvider.layers.selectedLayer.actionStack.length;

  // Create a new text object for editing.
  final TextObject textObj = TextObject(
    text: 'Test Text',
    position: const Offset(10, 10),
    color: const Color.fromARGB(255, 0, 0, 0),
    size: 24,
  );
  // Add it to the current layer's action stack.
  appProvider.layers.selectedLayer.actionStack.add(
    UserActionDrawing(
      action: ActionType.text,
      positions: const <Offset>[Offset(10, 10)],
      textObject: textObj,
    ),
  );

  // Set as selected — triggers TextEditor build + dialog.
  appProvider.selectedTextObject = textObj;
  appProvider.update();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Toggle bold button if available (text_editor_dialog.dart has key, text_editor.dart does not).
  final Finder boldBtn = find.byKey(Keys.textEditorBoldButton);
  if (boldBtn.evaluate().isNotEmpty) {
    await tester.tap(boldBtn);
    await tester.pump();
    await tester.tap(boldBtn);
    await tester.pump();
  } else {
    // Fallback: find bold toggle by icon for text_editor.dart's inline dialog.
    final Finder boldIcon = find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.formatBold,
    );
    if (boldIcon.evaluate().isNotEmpty) {
      final Finder boldIconBtn = find.ancestor(
        of: boldIcon.first,
        matching: find.byType(AppButtonIcon),
      );
      if (boldIconBtn.evaluate().isNotEmpty) {
        await tester.tap(boldIconBtn.first);
        await tester.pump();
        await tester.tap(boldIconBtn.first);
        await tester.pump();
      }
    }
  }

  // Exercise font size slider if visible.
  final Finder sliderFinder = find.byType(AppSlider);
  if (sliderFinder.evaluate().isNotEmpty) {
    // Use timedDrag for more reliable gesture delivery.
    // warnIfMissed: false — slider may be obscured by dialog overlay.
    await tester.timedDrag(
      sliderFinder.first,
      const Offset(30, 0),
      const Duration(milliseconds: 200),
      warnIfMissed: false,
    );
    await tester.pump();
  }

  // Toggle italic button — find the AppSvgIcon with formatItalic.
  final Finder italicIcon = find.byWidgetPredicate(
    (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.formatItalic,
  );
  if (italicIcon.evaluate().isNotEmpty) {
    // Tap the parent AppButtonIcon.
    final Finder italicBtn = find.ancestor(
      of: italicIcon.first,
      matching: find.byType(AppButtonIcon),
    );
    if (italicBtn.evaluate().isNotEmpty) {
      await tester.tap(italicBtn.first);
      await tester.pump();
      await tester.tap(italicBtn.first);
      await tester.pump();
    }
  }

  // Cancel to dismiss the dialog without saving.
  final Finder cancelBtn = find.text(l10n.cancel);
  if (cancelBtn.evaluate().isNotEmpty) {
    await tester.tap(cancelBtn.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Re-open the text editor dialog for the delete test.
  appProvider.selectedTextObject = textObj;
  appProvider.update();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap delete button.
  final Finder deleteBtn = find.text(l10n.delete);
  if (deleteBtn.evaluate().isNotEmpty) {
    await tester.tap(deleteBtn.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Re-create text object and re-open editor for apply test.
  appProvider.layers.selectedLayer.actionStack.add(
    UserActionDrawing(
      action: ActionType.text,
      positions: const <Offset>[Offset(10, 10)],
      textObject: textObj,
    ),
  );
  appProvider.selectedTextObject = textObj;
  appProvider.update();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Apply.
  final Finder applyBtn = find.text(l10n.apply);
  if (applyBtn.evaluate().isNotEmpty) {
    await tester.tap(applyBtn.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Re-create text object and re-open editor for "apply with empty text" test.
  final TextObject textObj2 = TextObject(
    text: 'To Be Deleted',
    position: const Offset(20, 20),
    color: const Color.fromARGB(255, 0, 0, 0),
    size: 24,
  );
  appProvider.layers.selectedLayer.actionStack.add(
    UserActionDrawing(
      action: ActionType.text,
      positions: const <Offset>[Offset(20, 20)],
      textObject: textObj2,
    ),
  );
  appProvider.selectedTextObject = textObj2;
  appProvider.update();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Clear the text field and apply — triggers _deleteText().
  final Finder textFields = find.byType(AppTextField);
  if (textFields.evaluate().isNotEmpty) {
    await tester.enterText(textFields.first, '');
    await tester.pump();
  }
  final Finder applyBtn2 = find.text(l10n.apply);
  if (applyBtn2.evaluate().isNotEmpty) {
    await tester.tap(applyBtn2.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Ensure clean state.
  appProvider.selectedTextObject = null;
  appProvider.update();
  await tester.pump();

  // Remove only the test text actions (keep the original layer content).
  while (appProvider.layers.selectedLayer.actionStack.length > stackLengthBefore) {
    appProvider.layers.selectedLayer.actionStack.removeLast();
  }
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection tool panel buttons
// ---------------------------------------------------------------------------

/// Creates a selection via provider and exercises selector tool panel buttons.
Future<void> _exerciseSelectionToolPanel(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Ensure selector tool is active.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  // Create a selection programmatically so tool panel buttons appear.
  final double w = appProvider.layers.width;
  final double h = appProvider.layers.height;
  appProvider.selectorModel.path1 = Path()..addRect(Rect.fromLTWH(w / 4, h / 4, w / 2, h / 2));
  appProvider.selectorModel.isVisible = true;
  appProvider.update();
  await tester.pump();

  // Tap circle selector mode.
  final Finder circleMode = find.byKey(Keys.toolSelectorModeCircle);
  if (circleMode.evaluate().isNotEmpty) {
    await tester.tap(circleMode);
    await tester.pump();
  }

  // Tap wand selector mode.
  final Finder wandMode = find.byKey(Keys.toolSelectorModeWand);
  if (wandMode.evaluate().isNotEmpty) {
    await tester.tap(wandMode);
    await tester.pump();
  }

  // Tap rectangle mode back.
  await tapByKey(tester, Keys.toolSelectorModeRectangle);
  await tester.pump();

  // Exercise selector math modes while selection is visible.
  // Re-create selection since mode switching may clear it.
  appProvider.selectorModel.path1 = Path()..addRect(Rect.fromLTWH(w / 4, h / 4, w / 2, h / 2));
  appProvider.selectorModel.isVisible = true;
  appProvider.update();
  await tester.pump();

  await setSelectorMathAdd(tester);
  await setSelectorMathRemove(tester);
  await setSelectorMathReplace(tester);

  // Cancel selection.
  final Finder cancelBtn = find.byKey(Keys.toolSelectorCancel);
  if (cancelBtn.evaluate().isNotEmpty) {
    await tester.tap(cancelBtn);
    await tester.pump();
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection flip/rotate
// ---------------------------------------------------------------------------

/// Makes a selection and exercises flip H/V and rotate 90° on it.
Future<void> _exerciseSelectionFlipRotate(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  // Ensure selector tool is active.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  // Create a selection programmatically.
  final double w = appProvider.layers.width;
  final double h = appProvider.layers.height;
  appProvider.selectorModel.path1 = Path()..addRect(Rect.fromLTWH(w / 4, h / 4, w / 2, h / 2));
  appProvider.selectorModel.isVisible = true;
  appProvider.update();
  await tester.pump();

  // Flip selection horizontal and back.
  await appProvider.flipCanvasHorizontal('Flip H selection');
  await tester.pump();
  await appProvider.flipCanvasHorizontal('Flip H sel back');
  await tester.pump();

  // Flip selection vertical and back.
  await appProvider.flipCanvasVertical('Flip V selection');
  await tester.pump();
  await appProvider.flipCanvasVertical('Flip V sel back');
  await tester.pump();

  // Rotate selection 90° and rotate back (3 more = 360).
  await appProvider.rotateCanvas90('Rotate selection 90');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate sel back 1');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate sel back 2');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate sel back 3');
  await tester.pump();

  // Undo all 8 self-canceling transforms to restore layer actionStacks.
  for (int i = 0; i < 8; i++) {
    appProvider.undoAction();
    await tester.pump();
  }
  // Clear any remaining redo entries.
  appProvider.undoProvider.clear();
  await tester.pump();

  // Clear selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection crop and duplicate
// ---------------------------------------------------------------------------

/// Exercises regionDuplicate() + confirmImagePlacement(), regionCopy, regionCut.
Future<void> _exerciseSelectionCropAndDuplicate(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Create a small selection for duplicate.
  appProvider.selectorModel.path1 = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
  appProvider.selectorModel.isVisible = true;
  appProvider.update();
  await tester.pump();

  // Duplicate selection.
  await appProvider.regionDuplicate();
  await tester.pump();

  // Confirm the image placement.
  if (appProvider.imagePlacementModel.isVisible) {
    await appProvider.confirmImagePlacement();
    await tester.pump();

    // Undo the placement.
    await _undoTimes(tester, 1);
  }

  // Clear selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Menu dialogs
// ---------------------------------------------------------------------------

/// Opens and closes the main menu to exercise menu build code.
Future<void> _exerciseMenuDialogs(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Dismiss.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Canvas transforms (no selection)
// ---------------------------------------------------------------------------

/// Exercises canvas rotate-90 and flip H/V when no selection is active.
Future<void> _exerciseCanvasTransforms(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final LayersProvider layersProvider = LayersProvider.of(context);
  // Ensure no selection is active.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  final double originalWidth = layersProvider.width;
  final double originalHeight = layersProvider.height;

  // Rotate canvas 90deg and rotate back with 3 more (4×90=360).
  await appProvider.rotateCanvas90('Rotate 90');
  await tester.pump();

  expect(layersProvider.width, originalHeight);
  expect(layersProvider.height, originalWidth);

  await appProvider.rotateCanvas90('Rotate back 1');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate back 2');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate back 3');
  await tester.pump();

  expect(layersProvider.width, originalWidth);
  expect(layersProvider.height, originalHeight);

  // Flip canvas horizontal and back.
  await appProvider.flipCanvasHorizontal('Flip H');
  await tester.pump();
  await appProvider.flipCanvasHorizontal('Flip H back');
  await tester.pump();

  // Flip canvas vertical and back.
  await appProvider.flipCanvasVertical('Flip V');
  await tester.pump();
  await appProvider.flipCanvasVertical('Flip V back');
  await tester.pump();

  // Exercise resetView.
  appProvider.resetView();
  await tester.pump();

  // Exercise canvasFitToContainer.
  appProvider.canvasFitToContainer(containerWidth: 800, containerHeight: 600);
  await tester.pump();

  // Exercise canvas pan.
  appProvider.canvasPan(offsetDelta: const Offset(10, 10));
  await tester.pump();

  // Exercise applyScaleToCanvas.
  appProvider.applyScaleToCanvas(scaleDelta: 1.5, anchorPoint: const Offset(400, 300));
  await tester.pump();

  // Reset back for remaining tests.
  appProvider.resetView();
  await tester.pump();

  // Exercise rotate/flip WITH active selection, then reverse each.
  appProvider.selectAll();
  await tester.pump();

  await appProvider.rotateCanvas90('Rotate with selection');
  await tester.pump();
  // Reverse: 3 more rotations = 360 total.
  await appProvider.rotateCanvas90('Rotate sel back 1');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate sel back 2');
  await tester.pump();
  await appProvider.rotateCanvas90('Rotate sel back 3');
  await tester.pump();

  await appProvider.flipCanvasHorizontal('Flip H with selection');
  await tester.pump();
  await appProvider.flipCanvasHorizontal('Flip H sel back');
  await tester.pump();

  await appProvider.flipCanvasVertical('Flip V with selection');
  await tester.pump();
  await appProvider.flipCanvasVertical('Flip V sel back');
  await tester.pump();

  // All transforms are self-canceling. Undo the 8 selection transforms to
  // restore layer actionStacks, then clear remaining (canvas) undo entries.
  for (int i = 0; i < 8; i++) {
    appProvider.undoAction();
    await tester.pump();
  }
  appProvider.undoProvider.clear();
  await tester.pump();

  // Clear selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  // Reset view one more time.
  appProvider.resetView();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection operations
// ---------------------------------------------------------------------------

/// Exercises selection using rectangle area.
Future<void> _exerciseSelectionOperations(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Ensure selector tool is active.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  // Select a rectangle area.
  await selectRectangleArea(
    tester,
    startPosition: session.canvasCenter - const Offset(_coverageSelectionMargin, _coverageSelectionMargin),
    endPosition: session.canvasCenter + const Offset(_coverageSelectionMargin, _coverageSelectionMargin),
  );

  // Selection may or may not be visible depending on canvas state.
  if (appProvider.selectorModel.isVisible) {
    appProvider.selectorModel.invert(
      Rect.fromLTWH(
        0,
        0,
        appProvider.layers.width,
        appProvider.layers.height,
      ),
    );
    appProvider.update();
    await tester.pump();
  }

  // Clear selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Blend mode
// ---------------------------------------------------------------------------

/// Exercises the blend mode on a layer.
Future<void> _exerciseLayerBlendMode(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  for (int i = 0; i < layersProvider.length; i++) {
    if (layersProvider.get(i).name == _skyLayerName) {
      layersProvider.get(i).blendMode = BlendMode.multiply;
      layersProvider.update();
      await tester.pump();
      expect(layersProvider.get(i).blendMode, BlendMode.multiply);

      layersProvider.get(i).blendMode = BlendMode.srcOver;
      layersProvider.update();
      await tester.pump();
      break;
    }
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Side panel buttons
// ---------------------------------------------------------------------------

/// Taps the side panel buttons to cover their onPressed callbacks.
Future<void> _exerciseSidePanelButtons(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Tap rotate canvas button in side panel.
  await tapByTooltip(tester, l10n.rotateCanvasTooltip);
  await tester.pump();

  // Rotate 3 more times to return to original (4×90=360).
  await tapByTooltip(tester, l10n.rotateCanvasTooltip);
  await tester.pump();
  await tapByTooltip(tester, l10n.rotateCanvasTooltip);
  await tester.pump();
  await tapByTooltip(tester, l10n.rotateCanvasTooltip);
  await tester.pump();

  // Tap flip horizontal button and flip back.
  await tapByTooltip(tester, l10n.flipHorizontalTooltip);
  await tester.pump();
  await tapByTooltip(tester, l10n.flipHorizontalTooltip);
  await tester.pump();

  // Tap flip vertical button and flip back.
  await tapByTooltip(tester, l10n.flipVerticalTooltip);
  await tester.pump();
  await tapByTooltip(tester, l10n.flipVerticalTooltip);
  await tester.pump();

  // Clear undo entries from the self-canceling transforms.
  appProvider.undoProvider.clear();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Canvas settings dialog
// ---------------------------------------------------------------------------

/// Opens the canvas settings dialog via the main menu and exercises its controls.
Future<void> _exerciseCanvasSettingsDialog(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Open main menu.
  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap "Canvas Size" menu item by its text.
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  final Finder canvasMenuItem = find.text(l10n.canvas);
  await tester.tap(canvasMenuItem);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Toggle aspect ratio lock button.
  await tapByKey(tester, Keys.canvasSettingsAspectRatioToggleButton);
  await tester.pump();

  // Toggle it back.
  await tapByKey(tester, Keys.canvasSettingsAspectRatioToggleButton);
  await tester.pump();

  // Tap apply with current (unchanged) values.
  await tapByKey(tester, Keys.canvasSettingsApplyButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// More tool switching
// ---------------------------------------------------------------------------

/// Switches through line, rectangle, circle, fill, and text tools to cover
/// their tool-option panels in tools_panel.dart.
Future<void> _exerciseMoreToolSwitching(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Line tool.
  await tapByKey(tester, Keys.toolLine);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.line);

  // Rectangle tool.
  await tapByKey(tester, Keys.toolRectangle);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.rectangle);

  // Circle tool.
  await tapByKey(tester, Keys.toolCircle);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.circle);

  // Fill tool.
  await tapByKey(tester, Keys.toolFill);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.fill);

  // Text tool.
  await tapByKey(tester, Keys.toolText);
  await tester.pump();
  expect(appProvider.selectedAction, ActionType.text);

  // Switch fill sub-modes.
  await tapByKey(tester, Keys.toolFill);
  await tester.pump();
  await tapByKey(tester, Keys.toolFillModeLinear);
  await tester.pump();
  await tapByKey(tester, Keys.toolFillModeSolid);
  await tester.pump();

  // Switch back to selector.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Drawing with shape tools
// ---------------------------------------------------------------------------

/// Actually draws shapes using line, rectangle, and circle tools on the canvas.
Future<void> _exerciseShapeDrawing(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Switch to line tool and draw.
  await tapByKey(tester, Keys.toolLine);
  await tester.pump();

  await drawFreehandStrokeWithHumanGestures(
    tester,
    points: <Offset>[
      session.canvasCenter + const Offset(-30, 0),
      session.canvasCenter + const Offset(30, 0),
    ],
    action: ActionType.line,
    brushSize: _coverageBrushSize,
  );

  await _undoTimes(tester, 1);

  // Switch to rectangle tool and draw.
  await tapByKey(tester, Keys.toolRectangle);
  await tester.pump();

  await drawFreehandStrokeWithHumanGestures(
    tester,
    points: <Offset>[
      session.canvasCenter + const Offset(-25, -25),
      session.canvasCenter + const Offset(25, 25),
    ],
    action: ActionType.rectangle,
    brushSize: _coverageBrushSize,
  );

  await _undoTimes(tester, 1);

  // Switch to circle tool and draw.
  await tapByKey(tester, Keys.toolCircle);
  await tester.pump();

  await drawFreehandStrokeWithHumanGestures(
    tester,
    points: <Offset>[
      session.canvasCenter + const Offset(-20, -20),
      session.canvasCenter + const Offset(20, 20),
    ],
    action: ActionType.circle,
    brushSize: _coverageBrushSize,
  );

  await _undoTimes(tester, 1);

  // Switch to fill tool (solid) and tap on the canvas.
  await tapByKey(tester, Keys.toolFill);
  await tester.pump();
  await tapByKey(tester, Keys.toolFillModeSolid);
  await tester.pump();

  // Perform a tap on the canvas to trigger flood fill.
  // floodFillSolidAction is async (fire-and-forget), so use runAsync to let
  // the real async computation finish before undoing.
  final BuildContext sdContext = tester.element(find.byType(MainView));
  final AppProvider sdAppProvider = AppProvider.of(sdContext, listen: false);
  final int stackBefore = sdAppProvider.layers.selectedLayer.actionStack.length;
  await tester.tapAt(session.canvasCenter);
  await tester.runAsync(() async {
    // Give the async fill time to complete.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();

  // Only undo if the fill actually completed and added an action.
  if (sdAppProvider.layers.selectedLayer.actionStack.length > stackBefore) {
    await _undoTimes(tester, 1);
  }

  // Switch back to selector.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

/// Collapses and re-expands the side panel to cover the toggle button callback.
Future<void> _exerciseSidePanelToggle(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final ShellProvider shellProvider = ShellProvider.of(context);

  // Collapse side panel.
  shellProvider.isSidePanelExpanded = false;
  await tester.pump();

  // Expand it back.
  shellProvider.isSidePanelExpanded = true;
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Layer rename dialog
// ---------------------------------------------------------------------------

/// Long-presses a layer thumbnail to open the popup menu, then exercises
/// the rename dialog.
Future<void> _exerciseLayerRenameDialog(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);

  // Find a LayerThumbnail widget and long press to trigger popup menu.
  final Finder thumbnails = find.byType(LayerThumbnail);
  expect(thumbnails, findsWidgets);

  await tester.longPress(thumbnails.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // The popup menu should be visible. Find the "Rename" option and tap it.
  final AppLocalizations l10n = context.l10n;
  final Finder renameItem = find.text(l10n.layerRename);
  if (renameItem.evaluate().isNotEmpty) {
    await tester.tap(renameItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

    // Type a new name in the rename text field.
    final Finder renameField = find.byKey(Keys.layerRenameTextField);
    if (renameField.evaluate().isNotEmpty) {
      final String originalName = layersProvider.selectedLayer.name;
      await tester.enterText(renameField, _coverageRenamedLayerName);
      await tester.pump();

      // Tap apply.
      await tapByKey(tester, Keys.layerRenameApplyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

      expect(layersProvider.selectedLayer.name, _coverageRenamedLayerName);

      // Rename does not use the undo stack, so restore the name directly.
      layersProvider.selectedLayer.name = originalName;
      layersProvider.update();
      await tester.pump();
    }
  } else {
    // Dismiss popup if rename not found.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Menu navigations
// ---------------------------------------------------------------------------

/// Navigates to settings and platforms pages via menu selections.
Future<void> _exerciseMenuNavigations(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;

  // Open menu and tap Settings.
  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  final Finder settingsItem = find.text(l10n.settings);
  if (settingsItem.evaluate().isNotEmpty) {
    await tester.tap(settingsItem.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
    // Go back by finding the back button (AppIcon.arrowLeft).
    final Finder backBtn = find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.arrowLeft,
    );
    if (backBtn.evaluate().isNotEmpty) {
      final Finder parentBtn = find.ancestor(
        of: backBtn.first,
        matching: find.byType(AppButtonIcon),
      );
      if (parentBtn.evaluate().isNotEmpty) {
        await tester.tap(parentBtn.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
      }
    }
  }

  // Open menu and tap Platforms.
  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  final Finder platformsItem = find.text(l10n.platforms);
  if (platformsItem.evaluate().isNotEmpty) {
    await tester.tap(platformsItem.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
    // Go back.
    final Finder backBtn2 = find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.arrowLeft,
    );
    if (backBtn2.evaluate().isNotEmpty) {
      final Finder parentBtn2 = find.ancestor(
        of: backBtn2.first,
        matching: find.byType(AppButtonIcon),
      );
      if (parentBtn2.evaluate().isNotEmpty) {
        await tester.tap(parentBtn2.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
      }
    }
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Shell mode toggle
// ---------------------------------------------------------------------------

/// Toggles the shell mode to hidden and back to cover those code paths.
Future<void> _exerciseShellModeToggle(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final ShellProvider shellProvider = ShellProvider.of(context);

  // Switch to hidden mode.
  shellProvider.shellMode = ShellMode.hidden;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  // Switch back to full mode.
  shellProvider.shellMode = ShellMode.full;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  // Exercise small device mode (mobile phone layout).
  shellProvider.deviceSizeSmall = true;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  // The zoom buttons may be visible; just pump to render the mobile layout.

  // Show mobile menu overlay.
  shellProvider.showMenu = true;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  // Hide mobile menu overlay.
  shellProvider.showMenu = false;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  // Switch back to normal mode.
  shellProvider.deviceSizeSmall = false;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Tool color pickers
// ---------------------------------------------------------------------------

/// Taps the brush and fill color preview buttons to trigger the color picker.
Future<void> _exerciseToolColorPickers(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Switch to line tool so color options appear.
  await tapByKey(tester, Keys.toolLine);
  await tester.pump();

  // Tap the brush color preview to open color picker.
  final Finder brushColorPreview = find.byKey(Keys.toolPanelBrushColor1);
  if (brushColorPreview.evaluate().isNotEmpty) {
    await tester.tap(brushColorPreview);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

    // Dismiss color picker dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Tap the fill color preview to open color picker.
  final Finder fillColorPreview = find.byKey(Keys.toolPanelFillColor);
  if (fillColorPreview.evaluate().isNotEmpty) {
    await tester.tap(fillColorPreview);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

    // Dismiss color picker dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
  }

  // Switch back to selector.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Layer add and delete
// ---------------------------------------------------------------------------

/// Adds a new layer via the popup menu and then deletes it.
Future<void> _exerciseLayerAddDelete(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final AppLocalizations l10n = context.l10n;
  final int originalCount = layersProvider.length;

  // Long press on a layer thumbnail to open popup menu.
  final Finder thumbnails = find.byType(LayerThumbnail);
  expect(thumbnails, findsWidgets);
  await tester.longPress(thumbnails.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap "Add layer" option.
  final Finder addItem = find.text(l10n.layerAddAbove);
  if (addItem.evaluate().isNotEmpty) {
    await tester.tap(addItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
    expect(layersProvider.length, originalCount + 1);

    // Undo the add to restore the original state (the add pushed to
    // the undo stack via executeAction).
    await _undoTimes(tester, 1);
    expect(layersProvider.length, originalCount);

    // Clear the undo/redo stack so the redo entry doesn't leak into
    // subsequent exercises (e.g. _exerciseFloatingButtons taps redo).
    final AppProvider addDelAppProvider = AppProvider.of(context, listen: false);
    addDelAppProvider.undoProvider.clear();
  } else {
    // Dismiss popup.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Floating action buttons
// ---------------------------------------------------------------------------

/// Taps the floating zoom and center buttons to cover their callbacks.
Future<void> _exerciseFloatingButtons(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final ShellProvider shellProvider = ShellProvider.of(context);

  shellProvider.shellMode = ShellMode.full;
  shellProvider.deviceSizeSmall = false;
  shellProvider.showMenu = false;
  shellProvider.update();
  await tester.pump();
  await tester.pump();

  appProvider.undoProvider.clear();
  appProvider.undoProvider.executeAction(
    name: _coverageFloatingUndoActionName,
    forward: () {},
    backward: () {},
  );
  await tester.pump();
  await tester.pump();

  // Tap undo floating button.
  await tapByKey(tester, Keys.floatActionUndo);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap redo floating button.
  await tapByKey(tester, Keys.floatActionRedo);
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  appProvider.undoProvider.clear();

  // Tap zoom in.
  await tapByKey(tester, Keys.floatActionZoomIn);
  await tester.pump();

  // Tap zoom out.
  await tapByKey(tester, Keys.floatActionZoomOut);
  await tester.pump();

  // Tap center.
  await tapByKey(tester, Keys.floatActionCenter);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection via gesture
// ---------------------------------------------------------------------------

/// Draws a selection rectangle using actual pointer events on the canvas,
/// then exercises transform and selection overlay drag handles.
Future<void> _exerciseSelectionViaGesture(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Ensure selector tool is active.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  // Make sure no selection exists.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  // Draw a selection rectangle via mouse gesture on the canvas.
  final Offset topLeft = session.canvasCenter + const Offset(-60, -60);
  final Offset bottomRight = session.canvasCenter + const Offset(60, 60);

  final TestGesture gesture = await tester.startGesture(
    topLeft,
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryButton,
  );
  await tester.pump();

  await gesture.moveTo(bottomRight);
  await tester.pump();

  await gesture.up();
  await tester.pump();

  // The selector should now be visible.
  if (appProvider.selectorModel.isVisible) {
    // Tap the transform button to enter transform mode.
    await tapByTooltip(tester, context.l10n.transform);
    await tester.pump();

    if (appProvider.transformModel.isVisible) {
      // Drag the transform center handle to move the selection.
      final Offset selectionCenter = session.canvasCenter;
      final TestGesture dragGesture = await tester.startGesture(
        selectionCenter,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump();
      await dragGesture.moveTo(selectionCenter + const Offset(20, 20));
      await tester.pump();
      await dragGesture.up();
      await tester.pump();

      // Apply the transform.
      await tapByTooltip(tester, context.l10n.apply);
      await tester.pump();

      // Undo the transform to restore the drawing.
      await _undoTimes(tester, 1);
    }
  }

  // Clean up selection.
  appProvider.selectorModel.clear();
  appProvider.transformModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Layer tap interactions
// ---------------------------------------------------------------------------

/// Taps and double-taps layer thumbnails to exercise layer selection and
/// visibility toggle in the layers panel.
Future<void> _exerciseLayerTapInteractions(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final int originalIndex = layersProvider.selectedLayerIndex;

  // Find layer thumbnails.
  final Finder thumbnails = find.byType(LayerThumbnail);
  expect(thumbnails, findsWidgets);

  // Tap a different layer (if more than one exists).
  if (thumbnails.evaluate().length > 1) {
    await tester.tap(thumbnails.at(1));
    await tester.pump();

    // Double-tap to toggle visibility.
    await tester.tap(thumbnails.at(1));
    await tester.pump();
    await tester.tap(thumbnails.at(1));
    await tester.pump();

    // Tap back to original layer.
    await tester.tap(thumbnails.first);
    await tester.pump();
  }

  // Restore.
  layersProvider.selectedLayerIndex = originalIndex;
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Tool panel buttons (brush size, brush style, eye-drop, tolerance)
// ---------------------------------------------------------------------------

/// Taps buttons in the tools panel to exercise callback paths in tools_panel.dart.
Future<void> _exerciseToolPanelButtons(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;

  // Switch to pencil tool to get brush size button.
  await tapByTooltip(tester, l10n.toolPencil);
  await tester.pump();

  // Tap brush size button to open picker dialog.
  final Finder brushSizeButton = find.byKey(Keys.toolBrushSizeButton);
  if (brushSizeButton.evaluate().isNotEmpty) {
    await tester.tap(brushSizeButton);
    await tester.pumpAndSettle();
    // Dismiss dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  // Switch to brush tool to get brush style button.
  await tapByTooltip(tester, l10n.toolBrush);
  await tester.pump();

  // Find and tap the brush style button (AppIcon.lineStyle).
  final Finder lineStyleButton = find.ancestor(
    of: find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.lineStyle,
    ),
    matching: find.byType(AppButtonIcon),
  );
  if (lineStyleButton.evaluate().isNotEmpty) {
    await tester.tap(lineStyleButton.first);
    await tester.pumpAndSettle();
    // Dismiss popup.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  // Switch to fill tool to exercise tolerance picker.
  await tapByTooltip(tester, l10n.toolPaintBucket);
  await tester.pump();

  // Tap tolerance button (AppIcon.support).
  final Finder toleranceButton = find.ancestor(
    of: find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.support,
    ),
    matching: find.byType(AppButtonIcon),
  );
  if (toleranceButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(toleranceButton.first);
    await tester.pump();
    await tester.tap(toleranceButton.first);
    await tester.pumpAndSettle();
    // Dismiss dialog.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  // Exercise top colors refresh button.
  final Finder refreshButton = find.ancestor(
    of: find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.refresh,
    ),
    matching: find.byType(AppButtonIcon),
  );
  if (refreshButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(refreshButton.first);
    await tester.pump();
    await tester.tap(refreshButton.first);
    await tester.pump();
  }

  // Switch back to pencil.
  await tapByTooltip(tester, l10n.toolPencil);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Layer popup menu actions (visibility, hideAll, showAll, merge)
// ---------------------------------------------------------------------------

/// Exercises layer popup menu actions that aren't covered elsewhere.
Future<void> _exerciseLayerPopupMenuActions(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final LayersProvider layersProvider = LayersProvider.of(context);
  final AppLocalizations l10n = context.l10n;

  // Ensure we have at least 2 layers.
  if (layersProvider.length < 2) {
    layersProvider.addTop();
    await tester.pump();
  }

  // Select first layer.
  layersProvider.selectedLayerIndex = 0;
  await tester.pump();

  // Find the layer selector's popup menu (more_vert icon) via AppPopupMenuButton.
  final Finder moreVertButtons = find.byWidgetPredicate(
    (final Widget w) => w is AppPopupMenuButton<String>,
  );

  if (moreVertButtons.evaluate().isNotEmpty) {
    // Open popup and tap "Hide".
    await tester.tap(moreVertButtons.first);
    await tester.pumpAndSettle();
    final Finder hideItem = find.text(l10n.layerHide);
    if (hideItem.evaluate().isNotEmpty) {
      await tester.tap(hideItem.first);
      await tester.pumpAndSettle();
    }

    // Open popup and tap "Show All".
    await tester.tap(moreVertButtons.first);
    await tester.pumpAndSettle();
    final Finder showAllItem = find.text(l10n.layerShowAll);
    if (showAllItem.evaluate().isNotEmpty) {
      await tester.tap(showAllItem.first);
      await tester.pumpAndSettle();
    }

    // Open popup and tap "Hide All Others".
    await tester.tap(moreVertButtons.first);
    await tester.pumpAndSettle();
    final Finder hideAllItem = find.text(l10n.layerHideAllOthers);
    if (hideAllItem.evaluate().isNotEmpty) {
      await tester.tap(hideAllItem.first);
      await tester.pumpAndSettle();
    }

    // Restore all visible.
    for (int i = 0; i < layersProvider.length; i++) {
      layersProvider.get(i).isVisible = true;
    }
    layersProvider.update();
    await tester.pump();

    // Open popup and tap "Merge Below" (if available).
    final int layerCountBeforeMerge = layersProvider.length;
    if (layersProvider.length > 1 && layersProvider.selectedLayerIndex < layersProvider.length - 1) {
      await tester.tap(moreVertButtons.first);
      await tester.pumpAndSettle();
      final Finder mergeItem = find.text(l10n.layerMergeBelow);
      if (mergeItem.evaluate().isNotEmpty) {
        await tester.tap(mergeItem.first);
        await tester.pumpAndSettle();

        // Undo the merge to restore the layer count.
        await _undoTimes(tester, 1);
        expect(layersProvider.length, layerCountBeforeMerge);
      }
    }
  }

  // Restore all layers visible after popup menu exercises.
  for (int i = 0; i < layersProvider.length; i++) {
    layersProvider.get(i).isVisible = true;
  }
  layersProvider.update();
  await tester.pump();

  // Tap the visibility toggle button directly.
  final Finder toggleButton = find.byTooltip(l10n.layerToggleVisibility);
  if (toggleButton.evaluate().isNotEmpty) {
    await tester.tap(toggleButton.first);
    await tester.pump();
    // Toggle back.
    final Finder toggleButton2 = find.byTooltip(l10n.layerToggleVisibility);
    if (toggleButton2.evaluate().isNotEmpty) {
      await tester.tap(toggleButton2.first);
      await tester.pump();
    }
  }

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Selection tool panel buttons (invert, effects, cancel via UI)
// ---------------------------------------------------------------------------

/// Creates a selection and then taps the tool panel buttons for invert,
/// effects, and cancel that are only visible when a selection is active.
Future<void> _exerciseSelectionToolPanelButtons(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);
  final AppLocalizations l10n = context.l10n;

  // Ensure selector tool is active.
  await tapByKey(tester, Keys.toolSelector);
  await tester.pump();

  // Create a selection.
  await selectRectangleArea(
    tester,
    startPosition: session.canvasCenter - const Offset(_coverageSelectionMargin, _coverageSelectionMargin),
    endPosition: session.canvasCenter + const Offset(_coverageSelectionMargin, _coverageSelectionMargin),
  );

  if (appProvider.selectorModel.isVisible) {
    // Tap "Invert" button in tool panel.
    final Finder invertButton = find.text(l10n.toolInvert);
    if (invertButton.evaluate().isNotEmpty) {
      await tester.tap(invertButton.first);
      await tester.pump();
    }

    // Tap "Cancel" button to clear selection.
    final Finder cancelButton = find.byKey(Keys.toolSelectorCancel);
    if (cancelButton.evaluate().isNotEmpty) {
      await tester.tap(cancelButton);
      await tester.pump();
    }
  }

  // Ensure selection is cleared.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Advanced selection operations
// ---------------------------------------------------------------------------

/// Exercises advanced selection features: transform, effects, wand mode,
/// and image placement cancel.
Future<void> _exerciseSelectionAdvanced(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Exercise cancelImagePlacement (no-op if nothing placed).
  appProvider.cancelImagePlacement();
  await tester.pump();

  // Exercise cancelTransform (no-op if nothing started).
  appProvider.cancelTransform();
  await tester.pump();

  // Exercise selectAll.
  appProvider.selectAll();
  await tester.pump();
  expect(appProvider.selectorModel.isVisible, true);

  // Exercise startTransform with active selection.
  await appProvider.startTransform();
  await tester.pump();

  // Cancel transform.
  appProvider.cancelTransform();
  await tester.pump();

  // Exercise regionErase with active selection.
  appProvider.selectAll();
  await tester.pump();
  appProvider.regionErase();
  await tester.pump();

  // Undo to restore.
  await _undoTimes(tester, 1);

  // Exercise selectorCreationStart with wand mode.
  appProvider.selectorModel.clear();
  appProvider.selectorModel.mode = SelectorMode.wand;
  appProvider.update();
  await tester.pump();

  appProvider.selectorCreationStart(session.canvasCenter);
  await tester.pump(const Duration(milliseconds: 500));

  appProvider.selectorCreationAdditionalPoint(
    session.canvasCenter + const Offset(10, 10),
  );
  await tester.pump();

  appProvider.selectorCreationEnd();
  await tester.pump();

  // Reset selector mode.
  appProvider.selectorModel.clear();
  appProvider.selectorModel.mode = SelectorMode.rectangle;
  appProvider.update();
  await tester.pump();

  // Exercise effect preview with a selection.
  appProvider.selectAll();
  await tester.pump();

  await appProvider.startEffectPreview(SelectionEffect.blur);
  await tester.pump();

  await appProvider.confirmEffectPreview();
  await tester.pump();

  // Undo the effect.
  await _undoTimes(tester, 1);

  // Exercise regionDuplicate and then confirmImagePlacement.
  appProvider.selectAll();
  await tester.pump();

  await appProvider.regionDuplicate();
  await tester.pump();

  await appProvider.confirmImagePlacement();
  await tester.pump();

  // Undo the paste.
  await _undoTimes(tester, 1);

  // Clear selection.
  appProvider.selectorModel.clear();
  appProvider.update();
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Canvas resize lock aspect ratio
// ---------------------------------------------------------------------------

/// Exercises canvas resize lock aspect ratio toggle.
Future<void> _exerciseCanvasResizeLockAspectRatio(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppProvider appProvider = AppProvider.of(context, listen: false);

  // Toggle lock aspect ratio.
  final bool original = appProvider.canvasResizeLockAspectRatio;
  appProvider.canvasResizeLockAspectRatio = !original;
  await tester.pump();
  expect(appProvider.canvasResizeLockAspectRatio, !original);

  appProvider.canvasResizeLockAspectRatio = original;
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Canvas settings validation errors
// ---------------------------------------------------------------------------

/// Exercises canvas settings validation error paths (non-numeric and negative).
Future<void> _exerciseCanvasSettingsValidation(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Open main menu.
  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap "Canvas Size" menu item.
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;
  await tester.tap(find.text(l10n.canvas));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Enter non-numeric width and tap apply → triggers "must be numbers" error.
  final Finder widthField = find.byKey(Keys.canvasSettingsWidthField);
  await tester.tap(widthField);
  await tester.enterText(widthField, 'abc');
  await tester.pump();
  await tapByKey(tester, Keys.canvasSettingsApplyButton);
  await tester.pump();
  // Wait for snackbar timer (4 seconds) to expire.
  await tester.pump(const Duration(seconds: 5));

  // Enter zero width → triggers "must be positive" error.
  await tester.tap(widthField);
  await tester.enterText(widthField, '0');
  final Finder heightField = find.byKey(Keys.canvasSettingsHeightField);
  await tester.tap(heightField);
  await tester.enterText(heightField, '100');
  await tester.pump();
  await tapByKey(tester, Keys.canvasSettingsApplyButton);
  await tester.pump();
  // Wait for snackbar timer (4 seconds) to expire.
  await tester.pump(const Duration(seconds: 5));

  // Exercise aspect-ratio-linked width/height fields.
  // First enable lock aspect ratio.
  await tapByKey(tester, Keys.canvasSettingsAspectRatioToggleButton);
  await tester.pump();

  // Change width — height should auto-update.
  await tester.tap(widthField);
  await tester.enterText(widthField, '200');
  await tester.pump();

  // Change height — width should auto-update.
  await tester.tap(heightField);
  await tester.enterText(heightField, '300');
  await tester.pump();

  // Disable lock.
  await tapByKey(tester, Keys.canvasSettingsAspectRatioToggleButton);
  await tester.pump();

  // Dismiss the dialog.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Tolerance picker slider & top colors
// ---------------------------------------------------------------------------

/// Exercises the tolerance picker slider and top-colors tap in the fill tool.
Future<void> _exerciseToleranceAndTopColors(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;

  // Switch to fill tool so tolerance picker and top colors are visible.
  await tapByKey(tester, Keys.toolFill);
  await tester.pump();

  // Find and drag the tolerance slider (AppSlider inside TolerancePicker).
  final Finder tolerancePicker = find.byType(TolerancePicker);
  if (tolerancePicker.evaluate().isNotEmpty) {
    final Finder sliderInTolerance = find.descendant(
      of: tolerancePicker.first,
      matching: find.byType(AppSlider),
    );
    if (sliderInTolerance.evaluate().isNotEmpty) {
      await tester.timedDrag(
        sliderInTolerance.first,
        const Offset(20, 0),
        const Duration(milliseconds: 200),
      );
      await tester.pump();
    }
  }

  // Tap a top-colors color swatch if visible.
  final Finder topColorsWidget = find.byType(TopColors);
  if (topColorsWidget.evaluate().isNotEmpty) {
    final Finder colorPreviews = find.descendant(
      of: topColorsWidget.first,
      matching: find.byType(ColorPreview),
    );
    if (colorPreviews.evaluate().isNotEmpty) {
      await tester.tap(colorPreviews.first);
      await tester.pump();
    }
  }

  // Switch back to pencil.
  final BuildContext fillContext = tester.element(find.byType(MainView));
  final AppLocalizations fillL10n = fillContext.l10n;
  await tapByTooltip(tester, fillL10n.toolPencil);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Brush style picker
// ---------------------------------------------------------------------------

/// Exercises the brush style picker dropdown.
Future<void> _exerciseBrushStylePicker(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext brushContext = tester.element(find.byType(MainView));
  final AppLocalizations brushL10n = brushContext.l10n;

  // Switch to brush tool.
  await tapByTooltip(tester, brushL10n.toolBrush);
  await tester.pump();

  // Find brush style picker (AppDropdown).
  final Finder dropdown = find.byType(AppDropdown<int>);
  if (dropdown.evaluate().isNotEmpty) {
    await tester.tap(dropdown.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

    // Tap a different style by its localized text.
    final Finder dashItem = find.text(brushL10n.brushStyleDash);
    if (dashItem.evaluate().isNotEmpty) {
      await tester.tap(dashItem.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
    } else {
      // Dismiss.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
    }
  }

  // Switch back to pencil.
  await tapByTooltip(tester, brushL10n.toolPencil);
  await tester.pump();

  await session.videoRecorder.captureFrame();
}

// ---------------------------------------------------------------------------
// Settings page
// ---------------------------------------------------------------------------

/// Navigates to settings page and exercises Apple Pencil toggle.
Future<void> _exerciseSettingsPage(
  final PaintingScenarioSession session,
) async {
  final WidgetTester tester = session.tester;
  final BuildContext context = tester.element(find.byType(MainView));
  final AppLocalizations l10n = context.l10n;

  // Open main menu.
  await tapByKey(tester, Keys.mainMenuButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

  // Tap Settings.
  final Finder settingsItem = find.text(l10n.settings);
  if (settingsItem.evaluate().isNotEmpty) {
    await tester.tap(settingsItem.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));

    // Toggle Apple Pencil setting if available.
    final Finder applePencilToggle = find.text(l10n.useApplePencilOnlyTitle);
    if (applePencilToggle.evaluate().isNotEmpty) {
      await tester.tap(applePencilToggle);
      await tester.pump();
      // Toggle back.
      await tester.tap(applePencilToggle);
      await tester.pump();
    }

    // Go back.
    final Finder backBtn = find.byWidgetPredicate(
      (final Widget w) => w is AppSvgIcon && w.icon == AppIcon.arrowLeft,
    );
    if (backBtn.evaluate().isNotEmpty) {
      final Finder parentBtn = find.ancestor(
        of: backBtn.first,
        matching: find.byType(AppButtonIcon),
      );
      if (parentBtn.evaluate().isNotEmpty) {
        await tester.tap(parentBtn.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: _coverageDialogTransitionMs));
      }
    }
  }

  await session.videoRecorder.captureFrame();
}
