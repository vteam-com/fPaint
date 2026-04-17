# AGENTS

## Coding Rules

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
