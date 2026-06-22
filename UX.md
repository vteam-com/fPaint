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

## Shell Visibility Rules

Side panel visibility is explicit shell state. Only the top-left shell button, the desktop splitter bar, or the `Tab` keyboard shortcut may change it.

Canvas gestures, editing overlays, placement/transform gestures, and scrim taps must preserve the current side panel state. See [SCENARIO_SIDE_PANEL_VISIBILITY](scenarios/SCENARIO_SIDE_PANEL_VISIBILITY.md).

## Top Toolbar Grouping Rules

Top shell toolbar controls are organized into stable domains rather than a flat list of independent buttons.

- Domains: document actions, history, selection, and viewport zoom.
- Each domain must stay inside one shared grouped surface whenever it is visible.
- Responsive compaction may remove lower-priority buttons from inside a domain, but it must not split a domain into separate standalone buttons or redistribute that domain across multiple surfaces.
- If a preserved domain still exceeds its responsive allocation, that domain may scroll horizontally inside its own grouped surface instead of forcing the overall top toolbar to overflow or ungroup adjacent domains.
- Entering selection mode may change only the selection domain contents. It must not ungroup the history, document, or zoom domains.
