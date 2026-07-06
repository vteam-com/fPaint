# AGENTS

## Coding Rules

- Use `const` for all compile-time constants and whenever possible for objects, collections, and constructors.
- Always use explicit, strong type annotations for variables, parameters, and return types. Avoid `var` and `dynamic` unless strictly necessary.

- Apply the DRY principle (Don't Repeat Yourself): Avoid code duplication by extracting reusable logic into functions, classes, or constants.
- Follow SOLID principles:
  - Single Responsibility: Each class/module should have one responsibility.
  - Open/Closed: Code should be open for extension, closed for modification.
  - Liskov Substitution: Subtypes must be substitutable for their base types.
  - Interface Segregation: Prefer many small, specific interfaces over large, general ones.
  - Dependency Inversion: Depend on abstractions, not concretions.

- Never introduce new magic numbers in code.
- Use named constants in `lib/helpers/constants.dart` (or the most relevant constants file) instead of inline numeric literals.
- If a numeric literal appears only once, still define a clearly named constant for it when it affects behavior, style, layout, timing, opacity, sizing, or thresholds.
- Before finalizing changes, scan modified files for inline numeric literals and replace them with constants.
- Never introduce new hardcoded strings in executable code.
- Every user-facing string must be localized through Flutter l10n (`AppLocalizations`) unless there is a technical reason not to localize.
- Non-user-facing tokens (e.g., protocol values, file format identifiers, action IDs, binding/runtime markers) must be declared as named `const String` values, not inline literals.

## Tool Design: Brushes & Effects

- Every pixel-changing tool lives in one **Brush** section and is used the same
  way — pick it, then paint. **Effects are brushes too**: tapping one arms it as
  a brush (size + strength) and you paint it on. In the panel an effect is a
  brush only; whole-layer/selection apply lives on the on-canvas selection
  overlay, not the panel. Selection is an orthogonal modifier that clips any
  tool and gates none.
- Do not add a separate section, an "effect mode" toggle, or a whole-region
  "Apply" button to the panel, and do not make one capability selectable in two
  places.
- **Read [BRUSHES_AND_EFFECTS.md](BRUSHES_AND_EFFECTS.md) before adding, moving,
  or renaming any tool or effect.** It is the canonical spec and holds the full
  invariants (one active tool at a time, region-bounded painting, and the
  bipolar-effect no-op commit guard — a strength-0 effect returns the same image
  instance, so any commit that disposes its source must check
  `identical(processed, source)` before drawing).

## Current Lint Context

- Magic number currently reported: `lib/main.dart` line 108 value `0.35`.
- Do not add similar inline values in future edits.

## Quality Gate

- After any code change, `tool/check.sh` must pass with a clean report before the work is considered complete.
- Fix all flagged issues (documentation, hardcoded strings, magic numbers, lint warnings) before finishing.

## Testing Rules

- When a test performs a tap (via `tapLikeHuman`, `tapByKey`, or `tapByTooltip`), a red target overlay must be drawn at the tap position and the frame saved to the video when a `UnitTestVideoRecorder` is active.
- Any new tap helper must call `UnitTestVideoRecorder.captureAfterInteraction(tester)` after performing the tap and recording the interaction.
- Before each tap or gesture in a test helper, capture a video frame with `UnitTestVideoRecorder.captureAfterInteraction(tester)` so the state before the interaction is visible in the recorded video.
