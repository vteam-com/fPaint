# Scenario: Selection-Aware Actions

## Goal

Ensure that pixel-level operations (copy, cut, duplicate, effects) behave consistently whether or not a selection exists.  When no selection is active the entire active layer is the implicit target — matching the convention established by Photoshop, GIMP, and other modern image editors.

## User Story

As a user, I want to press Cmd+C (or tap Copy) without first drawing a selection and have the entire active layer copied, so I don't have to manually "Select All" before every clipboard or effect operation.

## Design Principle
>
> **No selection = entire canvas is the selection.**

Any action that operates on "the selected region" must fall back to the full canvas bounds of the active layer when `selectorModel.path1` is `null`.

## Scope

### Actions that auto-select-all when no selection exists

| Action                                                                    | Entry Points                                 | Behavior without selection                           |
| ------------------------------------------------------------------------- | -------------------------------------------- | ---------------------------------------------------- |
| **Copy**                                                                  | Cmd+C / Ctrl+C, selection overlay button     | Copies entire active layer to clipboard              |
| **Cut**                                                                   | Cmd+X / Ctrl+X                               | Copies entire active layer, then erases it           |
| **Duplicate**                                                             | Cmd+D / Ctrl+D, selection overlay button     | Duplicates entire active layer as a new placed image |
| **Effects** (Blur, Sharpen, Pixelate, Grayscale, Noise, Soften, Vignette) | Selector tool panel, selection overlay popup | Applies effect to entire active layer                |

### Actions that remain gated on an existing selection

| Action                                      | Reason                                                           |
| ------------------------------------------- | ---------------------------------------------------------------- |
| **Crop**                                    | Requires explicit bounds; cropping to the full canvas is a no-op |
| **Invert selection**                        | Only meaningful when a selection already exists                  |
| **Selection math** (Replace / Add / Remove) | Only meaningful when refining an existing selection              |
| **Transform** (perspective / skew)          | Requires explicit region bounds                                  |
| **Cancel selection**                        | Only meaningful when a selection exists                          |

## Implementation Rules

1. `createSelectionImage()` — when `selectorModel.path1 == null`, call `selectAll()` first so the full canvas path is created, then proceed normally.
2. `applyEffect()` — when `selectorModel.path1 == null`, call `selectAll()` first.
3. The effects list in the **Selector tool panel** must be visible regardless of selection state (remove the `isVisible` guard on effect items).
4. After an auto-select-all fallback, the selection remains visible so the user can see what was affected.

## Preconditions

- A document is open with at least one layer containing pixel content.
- The active layer is visible and not locked.

## Undo / Redo

- Auto-select-all does **not** create its own undo entry; only the resulting operation (copy, effect, etc.) is undoable.
- The selection created by auto-select-all persists until the user dismisses it or draws a new one.

## Edge Cases

- Empty layer: copy/cut/duplicate may produce a transparent image — this is acceptable and matches standard editor behavior.
- Multiple layers: only the **active (selected) layer** is affected; other layers are untouched.
