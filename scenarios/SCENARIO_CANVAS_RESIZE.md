# Scenario: Canvas Resize

## Goal
Allow users to resize the canvas to custom dimensions while preserving and repositioning existing artwork according to a selected anchor point.

## User Story
As a user, I want to resize my canvas to specific dimensions (width/height in pixels) and choose how my existing artwork should be positioned relative to the new canvas bounds (top-left, center, bottom-right, etc.).

## Entry Points
- Side panel > "Canvas…" button opens the Canvas Size dialog.
- User enters desired width and height.
- User selects content alignment anchor (9-point grid).
- User clicks "Apply" to resize.

## Preconditions
- A document is open with existing canvas.
- User has access to the Canvas Size dialog.

## Functional Definition

### 1) User Input
- Width and height are entered as positive integers (pixels).
- Canvas aspect ratio can be locked to maintain proportion.
- Content alignment is selected from a 9-point grid (top-left, center, bottom-right, etc.).

### 2) Resize Operation
- Calculate offset translation based on anchor and old/new canvas dimensions using `anchorTranslate()`.
- Apply translation to all layer content (positions, paths, images, text).
- Update canvas size to the new dimensions.
- **Do not auto-scale the view**; keep view scale at 1.0 and zoom unchanged.

### 3) Visual Result
- Canvas dimensions visibly change to match user input.
- Artwork repositions according to the selected anchor (e.g., center anchor keeps content centered).
- No content cropping or clipping occurs; artwork may extend beyond new canvas or leave empty space.
- All layers maintain consistent relative positioning.

### 4) Undo / Redo
- Resize is a single undoable action named "Resize Canvas".
- Undo restores original canvas size and layer content offset.
- Redo reapplies the same resize deterministically.

### 5) Layer Behavior
- All layers are offset equally by the calculated translation.
- Layer sizes remain unchanged; only positions of drawing actions move.
- Background colors (if set) are preserved through resize/undo.

## Validation Rules
- Width and height must be positive integers.
- Canvas cannot resize to 0 or negative dimensions (error dialog shown).
- Invalid input (non-numeric) shows validation error.
- Aspect ratio lock prevents height/width from becoming invalid during linked updates.

## Non-goals (Out of Scope v1)
- Animated resize preview.
- Smart auto-resize based on content bounds.
- Canvas crop during resize.
- Batch resize multiple canvases.

## Edge Cases
- Resizing to same dimensions is a no-op (no undo entry).
- Resizing from 1×1 to 1000×1000 with first layer containing a single pixel: pixel remains visible at anchor point.
- Aspect ratio lock with rounding: height/width may differ by 1px due to integer conversion.
- Resizing canvas smaller than existing content: content is preserved but may extend beyond visible area.

## Acceptance Criteria
1. Given a 1024×768 canvas with artwork, when user resizes to 512×384 with center anchor, canvas displays as 512×384 and artwork remains centered.
2. When user undoes, canvas returns to 1024×768 and artwork returns to original position.
3. When user redoes, canvas is 512×384 again with centered artwork.
4. Canvas dimension display in floating button shows correct new width/height after resize.
5. Resizing with invalid dimensions (−1, 0, or non-numeric) shows snackbar error and does not apply.
6. After resize, view zoom level remains unchanged (no auto-fit).
7. All layer action types (positions, paths, images, text) are repositioned consistently.

## Suggested Tests

### Unit Tests
- Test `anchorTranslate()` returns correct offset for all 9 anchor positions.
- Test resize with same dimensions is no-op.
- Test resize validates positive integer input.
- Test undo/redo restores exact previous state.

### Widget Tests
- Test Canvas Size dialog opens and closes.
- Test aspect ratio lock toggle updates height when width changes.
- Test Apply button triggers resize with correct dimensions.
- Test validation error snackbar for invalid input.
- Test canvas dimensions display updates after Apply.

### Integration Tests
- Test full flow: draw on canvas → open Canvas dialog → enter new dimensions → click Apply → verify canvas resized and content repositioned → undo → redo.
- Test content anchor positions: top-left, center, bottom-right.
- Test layer content offsets match expected translation.

## Current Implementation Mapping
- Dialog UI: `lib/panels/side_panel/canvas_settings.dart`
- Resize logic: `lib/providers/layers_provider.dart` - `canvasResize()`
- Anchor translation: `lib/models/canvas_resize.dart` - `anchorTranslate()`
- Layer offset: `lib/providers/layer_provider.dart` - `offset()`

## Known Issues / Recent Fixes
- **Fixed**: Auto-view-scale during resize was masking canvas size changes.
- **Fixed**: Layer offset was only moving point positions; now moves paths, clipPaths, and text.
- **Fixed**: Canvas settings dialog now switches to manual placement mode after resize so new size is visually apparent.

---

This scenario defines the expected behavior for canvas resize and serves as a contract between design and implementation.
