# UX Layout Modes

This document defines the 4 primary application layouts.

## 1. Desktop

Full tool access with persistent controls and fast multi-step editing.

- Context: Large desktop landscape mode.
- Structure: Wide Side Panel on the left.
- Action FAB: On the right side.
- Available action buttons:
  - Selector toggle (Selector / Selector Cancel)
  - Undo (only when undo history exists)
  - Redo (only when redo history exists)
  - Zoom In
  - Center / Fit Canvas
  - Zoom Out
  - Hide Shell

## 2. Tablet

Preserve canvas visibility while keeping key actions one tap away.

- Context: Tablet landscape/portrait workflows.
- Structure: Left Side Panel is collapsed.
- Action FAB: On the right side.
- Available action buttons:
  - Selector toggle (Selector / Selector Cancel)
  - Undo (only when undo history exists)
  - Redo (only when redo history exists)
  - Zoom In
  - Center / Fit Canvas
  - Zoom Out
  - Hide Shell

## 3. Phone

Single-hand, quick-access editing flow on compact screens.

- Context: Small-screen mobile usage.
- Structure: UI prioritizes canvas area over persistent panels.
- Action FAB: Bottom-right cluster.
- Available action buttons (menu closed):
  - LEFT TO RIGHT
    - Undo (only when undo history exists)
    - Redo (only when redo history exists)
    - Tool/Menu Toggle (current tool icon)
    - Color Picker
    - Selector toggle (Selector / Selector Cancel)
- Available action buttons (menu open):
  - Close Menu

## 4. Full Surface Canvas

Use the entire surface for drawing, selection, and visual review.

- Context: Maximum drawing/viewing space mode.
- Structure: Side Panel is hidden.
- Action FAB: Minimal bottom-right trigger.
- Available action buttons:
  - Open Shell / More Actions
