# Rules

- fCheck shall always score 100%.
- When adding or fixing code, make sure there is a test for that change.
  - Apply the DRY principle (Don't Repeat Yourself): Avoid code duplication by extracting reusable logic into functions, classes, or constants.
  - Use `const` for all compile-time constants and whenever possible for objects, collections, and constructors.
  - Always use explicit, strong type annotations for variables, parameters, and return types. Avoid `var` and `dynamic` unless strictly necessary.
  - Follow SOLID principles:
    - Single Responsibility: Each class/module should have one responsibility.
    - Open/Closed: Code should be open for extension, closed for modification.
    - Liskov Substitution: Subtypes must be substitutable for their base types.
    - Interface Segregation: Prefer many small, specific interfaces over large, general ones.
    - Dependency Inversion: Depend on abstractions, not concretions.
- Make sure the tests are passing.
- Do not regress code coverage; improving it is encouraged.

## Version control

- **Never commit.** Do not run `git commit`, `git push`, `git tag`, or stage
  changes for a commit, and do not offer to. Committing is always the developer's
  action, so that every change is reviewed by a human before it enters history.
- Instead, when the work is done, leave the changes in the working tree and
  **suggest a commit message** for the developer to use or edit.
- Also leave generated artifacts out of the suggestion's scope when they were
  only touched by running the checks (`coverage/`, `fcheck_*.svg`,
  `test/output/`) — say which files are feature changes and which are churn.

## Tool design: Brushes & Effects

Every pixel-changing tool lives in one **Brush** section and is used the same
way — pick it, then paint. **Effects are brushes too**: tapping one arms it as a
brush (size + strength) and you paint it on. In the panel an effect is a brush
only — no whole-region "Apply" button; whole-layer/selection apply lives on the
on-canvas selection overlay. Selection is an orthogonal modifier that clips any
tool and gates none. Do not add a separate section or mode toggle, and do not
make one capability selectable in two places.

**Read [BRUSHES_AND_EFFECTS.md](BRUSHES_AND_EFFECTS.md) before adding, moving,
or renaming any tool or effect** — it holds the full invariants (one active
tool at a time, bipolar-effect no-op commit guard, region-bounded painting,
etc.).

## Platform UX

- The app is used primarily on desktop with the Side Panel visible. Effect controls, intensity sliders, and Apply/Cancel actions live in the Side Panel for that context.
- The app can also be used on a tablet or with the Side Panel collapsed. In those contexts, effect interactions are triggered via the on-canvas overlay (selection widget popup button) and presented in a bottom sheet that leaves the canvas fully visible so the user can see live preview while adjusting intensity.
