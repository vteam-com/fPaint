# Scenario: Side Panel Visibility Ownership

## Goal

Ensure that side panel visibility is controlled only by explicit shell controls. Drawing, transform, placement, and navigation gestures must never hide, collapse, or dismiss the side panel as a side effect.

## User Story

As a user, I want the side panel to stay in its current state while I draw, select, place, transform, pan, or zoom, so I only lose the panel when I intentionally change shell state.

## Design Principle

> **Side panel state is explicit shell state, not gesture side effect.**

The side panel may change state only through the shell controls listed in this document. Editing overlays and gestures may change panel content, but they must not change panel visibility.

## State Definitions

### Large layouts

| State         | Meaning                                                 |
| ------------- | ------------------------------------------------------- |
| **Expanded**  | Full side panel is visible at the normal desktop width. |
| **Collapsed** | Minimal/narrow side panel remains visible.              |
| **Hidden**    | The shell is hidden and no side panel is shown.         |

### Compact layouts

| State      | Meaning                                  |
| ---------- | ---------------------------------------- |
| **Open**   | The side panel is visible as an overlay. |
| **Closed** | The side panel overlay is not visible.   |

## Allowed State Changes

### 1. Top-left shell button

- This is the primary shell control.
- On large layouts it cycles through the 3 desktop states: **Expanded -> Collapsed -> Hidden -> Expanded**.
- On compact layouts it opens or closes the side panel overlay.

### 2. Desktop splitter bar

- Splitter interactions are the only pointer gestures allowed to affect side panel geometry.
- Dragging the splitter may resize a visible side panel.
- Double-tapping the splitter may toggle **Expanded** and **Collapsed**.
- Splitter interactions must not transition the shell to **Hidden**.

### 3. Keyboard shell toggle

- The keyboard shell toggle is an accepted non-gesture exception.
- Pressing `Tab` may toggle the shell between visible and hidden modes.
- This shortcut is allowed even though it is not part of the top-left button or splitter interaction model.

## Disallowed Triggers

The following must never change side panel visibility state:

- Canvas pan, zoom, pinch, stylus, or mouse gestures.
- Drawing gestures for brush, pencil, eraser, line, rectangle, circle, fill, or text placement.
- Selection creation, selection resize, selection move, selection rotate, or selection transform gestures.
- Image placement move, scale, rotate, or transform gestures.
- Entering or leaving image placement mode.
- Entering or leaving transform mode.
- Entering or leaving effect preview mode.
- Backdrop taps, scrim taps, or any other tap outside the side panel.
- Overlay presentation or dismissal that is not initiated by the allowed shell controls above.

## Layout Rules

1. `SidePanel` visibility must be derived from shell state only.
2. Editing overlay visibility must not mount or unmount `SidePanel` as a side effect.
3. If a mode needs specialized panel content, keep the panel visible and swap the content instead of hiding the panel.
4. Layer Modify mode is allowed to replace normal panel content with a minimal apply/cancel panel while preserving the current shell visibility state.
5. Compact-layout scrims may block background interaction, but tapping the scrim must not close the side panel.

## Acceptance Criteria

1. If the side panel is expanded, starting image placement leaves it expanded.
2. If the side panel is collapsed, starting image placement leaves it collapsed.
3. Switching from image placement to perspective transform preserves the current side panel state.
4. Completing or canceling image placement or transform preserves the current side panel state.
5. Backdrop taps do not close the side panel on compact layouts.
6. The top-left shell button still cycles the allowed states.
7. Splitter interactions still resize the panel and may toggle expanded/collapsed.
8. Pressing `Tab` still toggles shell visibility.

## Test Guidance

- Add widget coverage for image placement, transform, and modify flows while asserting that `shellMode`, `isSidePanelExpanded`, or `showMenu` stay unchanged unless the top-left shell button, splitter, or `Tab` shortcut is used.
- Add compact-layout coverage that verifies a scrim tap does not close an open side panel overlay.
