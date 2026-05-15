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
