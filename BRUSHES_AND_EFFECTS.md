# Brushes & Effects — the tool model

This is the single source of truth for how fPaint organizes the tools that
change pixels. Both the end-user help and the contributor rules point here.

If you are adding, moving, or renaming a tool, read the
[Design rules for contributors](#design-rules-for-contributors) section first.

---

## The core idea

**A brush is something you paint. Selection is a mask.**

Pixel-changing tools split by **interaction shape** into two side-panel
sections:

- **Brush** — freehand painters that deposit or move pixels along a stroke
  (pencil, brush, smudge, eraser), *plus the effects* (blur, sharpness,
  brightness, …). An effect is just a brush: pick one and it **arms as a
  brush**; paint to apply it along your stroke. In this section an effect *is*
  a brush — no separate "effect mode", no mode toggle, no per-effect "Apply"
  button. (Applying an effect to a whole region at once lives on the on-canvas
  selection overlay; see [Whole-region apply](#whole-region-apply).)
- **Elements** — placement / shape tools that commit a discrete shape, region,
  or text object from a click or two-point drag rather than a freehand stroke:
  line, rectangle, circle, fill (paint bucket), text. These are *not* brushes;
  grouping them under "Brush" was misleading, so they get their own section.

The gradient paint bucket is a small live editor: the first tap opens a
non-committed **preview session** with draggable handles; **Apply/Cancel** on
the on-canvas overlay finalizes it (see [Gradient fill sessions](#gradient-fill-sessions)).

---

## The two sections

The rail is two flat grids, in this order:

**Brush section** —
Gesture painters: Pencil · Brush · Smudge · Eraser.
Effects: Blur · Sharpness · Brightness · Contrast · Grayscale ·
Hue/Saturation · Noise · Pixelate · Shadow · Vignette.

**Elements section** — Line · Rectangle · Circle · Fill · Text.

| | Gesture tool | Effect |
|---|---|---|
| Backed by | `ActionType` | `SelectionEffect` |
| Tapping it | selects it as the active tool | arms it as a brush (tap again to disarm) |
| Options shown | that tool's params | brush **size** and **strength** |
| How it applies | paint / place | paint the stroke |

Exactly **one tool is active at a time across both sections**: arming an effect
deselects the gesture tool (and swaps in the effect's controls); picking any
gesture tool disarms the effect. The active tool's controls render beneath
whichever section owns it. The highlight, the options panel, and the actual
stroke behavior always agree on one active tool.

---

## Selection is a modifier, not a mode

The selection is **orthogonal**: it clips any tool and gates none.

- With a selection visible, both gesture strokes **and** effects are confined
  to it. This holds even while the **selector tool** is active: an armed effect
  brush paints (clipped to the selection) instead of starting a new marquee —
  the brush wins, the selection just clips it.
- With **no** selection, a stroke paints freely and a whole-region apply targets
  the **whole active layer** — an effect is never a silent no-op waiting for a
  selection.
- Switching tools never clears the selection. The visible selection marquee is
  the cue that the clip is live, and the toolbar's **Cancel Selection** button
  (the selector toggle, which flips to a cancel state whenever a selection
  exists) clears it.

---

## Painting an effect

An armed effect is laid down by **painting** it onto a band, the same as any
brush stroke. Painting stays **region-bounded** (cost scales with the brushed
area, not the whole canvas), so it stays off the slow full-canvas image-transfer
path.

## Whole-region apply

To filter an entire layer or selection at once (rather than brushing it), use
the **on-canvas selection overlay**: make a selection, then pick the effect from
the overlay popup. That opens a live-preview flow with Apply/Cancel
(`startEffectPreview` / `EffectIntensityControls`, presented in a bottom sheet on
compact layouts). The left-panel Brush section deliberately does **not** carry a
whole-region "Apply" button — in the panel, effects are brushes you paint.

---

## Effect strength: bipolar vs unipolar

Each effect declares its slider polarity:

- **Unipolar** (`0 → 1`): Blur, Grayscale, Noise, Pixelate, Shadow, Vignette.
  Zero means none; the slider only adds the effect.
- **Bipolar** (centered `− … 0 … +`): **Sharpness, Brightness, Contrast,
  Hue/Saturation.** The center (0) is no change and the **sign picks the
  direction** — darken/brighten, less/more contrast, hue ±, and for Sharpness,
  soften (blur) vs. sharpen. Bipolar effects default to a positive value so the
  brush does something out of the box; drag through 0 to reverse.

Sharpness folds the former separate "Sharpen" and "Edge Soften" into one signed
axis. Heavy blur stays the dedicated **Blur** effect.

---

## Gradient fill sessions

Solid fill commits immediately on tap. **Gradient** fill (linear/radial) opens a
live, bounded **preview session**:

- The first canvas tap seeds the gradient handles and lays a **non-committed
  preview** on the active layer — appended to the layer's action stack but
  **never** written to the undo stack.
- Dragging handles, editing stops/colors, or changing size re-renders the
  preview (debounced). Each re-render strips the previous transient first so the
  flood fill always samples the **clean** layer (otherwise the region shrinks).
- **Apply** (green check on the on-canvas overlay) commits the previewed fill as
  **exactly one** undoable action. **Cancel** (red X) discards it with **zero**
  undo entries.
- The session also finalizes implicitly: switching tools or undo/redo **applies**
  it; **Escape** cancels it. A monotonic version token drops stale async renders.

This replaced an older model that juggled `undoProvider.undo()` on every edit —
that blind undo corrupted the shared undo stack whenever anything else touched
it, which is why the bucket felt flaky.

---

## Design rules for contributors

These are the invariants. Breaking one is a design regression, not just a code
change.

1. **Two sections by interaction shape.** *Brush* holds the freehand painters
   (pencil, brush, smudge, eraser) and every effect, all used by
   picking-then-painting. *Elements* holds the placement/shape tools (line,
   rectangle, circle, fill, text). Do not move a placement tool into Brush or a
   freehand/effect tool into Elements, and do not add a third section or an
   "effect mode" toggle. Within Brush, an effect is still just a brush.

2. **In the panel, an effect is a brush — full stop.** A new effect must arm as
   a brush (size + strength controls) and be applied by painting. Do not add a
   whole-region "Apply" button to the panel; whole-region apply is the selection
   overlay's job (`startEffectPreview`), keeping the panel purely a brush
   palette.

3. **One capability, one place.** A given effect must not be selectable twice.
   (Blur is an effect only. The `blurBrush` `ActionType` and its pixel-brush
   engine are kept in code for rendering/export/prefs and a possible fast
   Apply-paint path, but it is **not** in the rail.)

4. **Selection clips, never gates.** Any new tool must honor a visible selection
   and must still work with no selection (targeting the whole active layer).

5. **One active tool at a time.** Arming an effect must disarm the gesture tool
   and vice-versa; highlight + options panel + stroke behavior must stay in
   agreement.

6. **Paint stays region-bounded.** Never route a painted effect stroke through a
   full-canvas transform — that hits the CPU↔GPU transfer wall. Bound it to the
   brushed region.

7. **Guard the no-op commit.** A bipolar effect at strength 0 returns the *same*
   image instance. Any commit path that disposes its captured source **must**
   check `identical(processed, source)` and bail before drawing, or it crashes
   with "non-genuine Image" (see `commitEffectBrushStroke`).

8. **Localize and constant-ize.** New tool/effect labels go through
   `AppLocalizations`; no inline strings or magic numbers (see
   [RULES.md](RULES.md) / [AGENTS.md](AGENTS.md)).

---

## Code map

| Concern | File |
|---|---|
| The rail (Brush + Elements sections: grids + active-tool controls) | [lib/panels/tools/tool_family_rail.dart](lib/panels/tools/tool_family_rail.dart) |
| Section orders + builders (`kBrushToolOrder`, `kElementToolOrder`, `brushSectionTools`, `elementSectionTools`) | [lib/models/tool_descriptor.dart](lib/models/tool_descriptor.dart) |
| Gesture tool labels | [lib/models/tool_family.dart](lib/models/tool_family.dart) |
| Effect definitions, polarity, `apply()` | [lib/models/selection_effect.dart](lib/models/selection_effect.dart) |
| Effect display labels | [lib/models/effect_labels.dart](lib/models/effect_labels.dart) |
| Armed effect-brush state | [lib/models/effect_brush_model.dart](lib/models/effect_brush_model.dart) |
| Gesture actions | [lib/models/user_action_drawing.dart](lib/models/user_action_drawing.dart) |
| Paint commit, overlay preview flow, selection clipping | [lib/providers/app_provider_selection_effects.dart](lib/providers/app_provider_selection_effects.dart) |
| Gradient fill preview session (update/apply/cancel) | [lib/providers/app_provider_tools.dart](lib/providers/app_provider_tools.dart) |
| Gradient fill on-canvas handles + Apply/Cancel overlay | [lib/widgets/fill_widget.dart](lib/widgets/fill_widget.dart) |
