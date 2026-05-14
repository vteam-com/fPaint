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

## Platform UX

- The app is used primarily on desktop with the Side Panel visible. Effect controls, intensity sliders, and Apply/Cancel actions live in the Side Panel for that context.
- The app can also be used on a tablet or with the Side Panel collapsed. In those contexts, effect interactions are triggered via the on-canvas overlay (selection widget popup button) and presented in a bottom sheet that leaves the canvas fully visible so the user can see live preview while adjusting intensity.
