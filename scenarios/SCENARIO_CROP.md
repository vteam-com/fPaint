# Scenario: Crop Canvas To Selection

## Goal
Allow users to reduce the canvas to the current selection bounds, while preserving selected pixel content, layer alignment, and undo/redo behavior.

## User Story
As a user, when I create a selection (rectangle, circle, lasso, or wand), I want to crop the document to that selection so I can remove unused space and focus the artwork.

## Entry Points
- Tool panel action: **Selector > Crop**
- Availability: only visible/enabled when a selection exists.

## Preconditions
- A document is open.
- A valid selection path exists.
- Selection bounds have positive width and height.

## Functional Definition

### 1) Crop Source
- Crop uses the bounding rectangle of the active selection path.
- For non-rectangular selections (circle/lasso/wand), crop still uses the rectangular bounds of that path.

### 2) Crop Operation
- Compute selection bounds: `left`, `top`, `width`, `height`.
- Compute content translation offset as:
	- `dx = -left`
	- `dy = -top`
- Apply translation to layer content so selected content moves to the new origin `(0, 0)`.
- Resize canvas to `(width, height)` using top-left anchoring.
- Clear selection after crop is applied.

### 3) Undo / Redo
- Crop is a single undoable action named **Crop**.
- Undo restores:
	- previous canvas size
	- previous content offset/alignment
- Redo reapplies the crop deterministically.

### 4) Multi-layer Behavior
- Crop applies to the full document state, not only the selected layer.
- Relative positioning between layers remains unchanged after crop.

### 5) UI Feedback
- Crop action executes immediately (no confirmation dialog in v1).
- Canvas updates after operation and reflects new dimensions.

## Validation Rules
- If there is no valid selection path, crop must not run.
- If selection bounds are empty/invalid (`width <= 0` or `height <= 0`), crop must not run.
- If selection extends outside current canvas, behavior should clamp effectively to drawable content by existing resize/offset logic (no crash).

## Non-goals (Out of Scope)
- Perspective or arbitrary-shape crop that preserves non-rectangular transparency mask.
- Interactive crop handles with live preview.
- Optional margins/padding around crop bounds.
- Confirmation dialog and advanced crop presets.

## Edge Cases
- Inverted or combined selection (add/remove math): crop uses resulting combined path bounds.
- One-pixel selection should produce a `1x1` crop if valid.
- Floating-point bounds are converted to integer canvas dimensions; result should be consistent across undo/redo.

## Acceptance Criteria
1. Given an active selection, when user clicks Crop, canvas size becomes selection bounding size.
2. The selected content appears in the same visual place relative to the new canvas origin.
3. The selection is cleared after crop.
4. Undo restores original canvas size and content placement.
5. Redo reapplies the same crop result.
6. Crop action is unavailable or no-op when no valid selection exists.
7. Crop does not crash for any selector mode (rectangle, circle, lasso, wand).

## Suggested Tests
- Unit test: crop computes correct translation from bounds.
- Unit test: crop resizes to integer dimensions expected from bounds.
- Unit test: undo/redo roundtrip restores exact previous canvas size and layer offsets.
- Widget/integration test: selector visible -> Crop action appears and executes.
- Integration test: combined selector math (add/remove) crops to final path bounds.

## Current Implementation Mapping
- Crop action entry: `lib/panels/tools/tools_panel.dart`
- Crop execution and undo integration: `lib/providers/app_provider.dart`

This scenario defines expected behavior for the current crop feature and can be used as baseline for future enhancements.
