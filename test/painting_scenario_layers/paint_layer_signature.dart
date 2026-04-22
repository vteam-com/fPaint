part of '../painting_scenario_test.dart';

Future<void> paintLayerSignature(
  final PaintingScenarioSession session, {
  required final LayersProvider layersProvider,
}) async {
  await PaintingLayerHelpers.addNewLayer(session.tester, _signatureLayerName);

  final Size croppedCanvasSize = layersProvider.size;
  final TextObject measureText = TextObject(
    text: _signatureText,
    position: Offset.zero,
    color: const Color.fromARGB(255, 1, 43, 8),
    size: _signatureFontSize,
    fontFamily: _signatureFontFamily,
    fontWeight: FontWeight.bold,
  );
  final Rect textBounds = measureText.getBounds();

  final Offset signaturePosition = Offset(
    croppedCanvasSize.width - textBounds.width - _signatureMarginRight,
    croppedCanvasSize.height - textBounds.height - _signatureMarginBottom,
  );

  await placeTextViaUI(
    session.tester,
    canvasPosition: signaturePosition,
    text: _signatureText,
    fontSize: _signatureFontSize,
    color: const Color.fromARGB(255, 1, 43, 8),
    fontWeight: FontWeight.bold,
    fontFamily: _signatureFontFamily,
  );

  final TextObject? signatureTextObject = layersProvider.selectedLayer.actionStack.isEmpty
      ? null
      : layersProvider.selectedLayer.actionStack.last.textObject;
  expect(signatureTextObject, isNotNull, reason: 'Signature layer should contain a text action');
  expect(signatureTextObject!.text, _signatureText);
  expect(signatureTextObject.fontFamily, _signatureFontFamily);
  expect(signatureTextObject.fontWeight, FontWeight.bold);
  expect(signatureTextObject.position.dx, closeTo(signaturePosition.dx, _signaturePositionTolerance));
  expect(signatureTextObject.position.dy, closeTo(signaturePosition.dy, _signaturePositionTolerance));

  await session.videoRecorder.captureFrame();
}
