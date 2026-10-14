part of '../painting_scenario_test.dart';

// Signature: the app's name, set in the bottom-right corner with the Text tool
// in a warm cream that picks up the sunset.

const String _signatureLayerName = 'Signature';
const String _signatureText = 'fPaint';

// The family name a font is REGISTERED under, not the pubspec `family:` key.
// Fonts from a package are namespaced as `packages/<pkg>/<family>`; the bare
// 'Inter' resolves to nothing and silently falls back to the test harness's
// block font, which renders the signature as a solid filled rectangle.
const String _signatureFontFamily = appFontFamily;
const double _signatureFontSize = 34.0;
const Color _signatureColor = Color(0xFFFFE6C7);
const double _signatureMarginRight = 22.0;
const double _signatureMarginBottom = 18.0;
const double _signaturePositionTolerance = 1.0;

Future<void> paintShowcaseSignature(
  PaintingScenarioSession session, {
  required LayersProvider layersProvider,
}) async {
  final WidgetTester tester = session.tester;
  await addLayerViaUi(tester, _signatureLayerName);

  // Dial in the font colour from the Text tool's own colour control first.
  await selectToolByKey(tester, Keys.toolText);
  await pickColorViaDialog(tester, previewKey: Keys.toolPanelFontColor, color: _signatureColor);
  await setTextSizeViaUi(tester, _signatureFontSize);

  final Size canvasSize = layersProvider.size;
  final TextObject measureText = TextObject(
    text: _signatureText,
    position: Offset.zero,
    color: _signatureColor,
    size: _signatureFontSize,
    fontFamily: _signatureFontFamily,
    fontWeight: FontWeight.bold,
  );
  final Rect textBounds = measureText.getBounds();
  final Offset signaturePosition = Offset(
    canvasSize.width - textBounds.width - _signatureMarginRight,
    canvasSize.height - textBounds.height - _signatureMarginBottom,
  );

  await placeTextViaUI(
    tester,
    canvasPosition: signaturePosition,
    text: _signatureText,
    fontSize: _signatureFontSize,
    color: _signatureColor,
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
