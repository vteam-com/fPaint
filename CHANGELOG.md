<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

## [1.8.4] - 2026-06-07

### Update

- Smudge and Blur stroke workflow improvements
- Selection and flood fill workflow polish

## [1.8.3] - 2026-05-29

### Fix

- Flood fill gradient handling
- Selection effect reliability

## [1.8.2] - 2026-05-29

### Add

- Polygon selection workflow
- Layer locking controls
- Additional blend modes
- ORA thumbnails in recent-file and import flows

### Update

- Saving now shows progress feedback
- Halftone size picker workflow
- Selection flood fill performance

### Fix

- Runtime crash in affected editing flows
- Linear paint fill rendering
- MRU handling and macOS bookmark-backed save reliability
- Bottom sheet dialog icon display

## [1.8.1] - 2026-05-27

### Add

- New Halftone and Solid Fill tool icons
- Duplicate move workflow with updated shortcut help
- Enable/disable toggle for tool attributes

### Fix

- HEIC decoding now uses the `image` package backend for more reliable imports
- AVIF file loading
- macOS MRU file loading
- Gradient color ordering in the side panel
- Tool attribute secondary controls now collapse correctly while disabled

## [1.8.0] - 2026-05-25

### Update

- Adaptive interaction profiles now scale toolbar and on-canvas controls for mouse, pen, and touch input.
- Toolbar, selector, transform, and overlay action buttons now use more consistent sizing and spacing across pointer modalities.

### Fix

- Custom app buttons now preserve pressed-state feedback more reliably during quick taps.
- Overlay and floating controls now handle tap and drag interactions more consistently.

## [1.7.5] - 2026-05-22

### Fix

- Selection and transform overlay controls now avoid clipping near the viewport edges:
  - Keep default top placement when there is room
  - Flip to bottom when top would clip
  - Fall back to centered placement when both top and bottom would clip
- Escape key handling now consistently cancels active selector and transform overlays

## [1.7.4] - 2026-05-15

### Added

- Enhance Transform
  - Toggle mode: Corners, Edges-Centers, All
  - Edges movement

## [1.7.3] - 2026-05-14

### Fix

- MRU
  - **macOS sandbox file access:** Recent files now use security-scoped bookmarks to maintain persistent access across sessions
  - Import dialog now shows appropriate placeholders for missing or unloadable files (e.g., TIFF, ORA)
  - Error feedback displayed when opening missing or unloadable recent files
  - Thumbnail loading distinguishes between "File not found" and "Preview unavailable" states
  - Discard button available for both missing and unloadable recent file entries

## [1.7.2] - 2026-05-10

### Update

- Update packages

## [1.7.1] - 2026-05-06

### Update

- improve flood fill

## [1.7.0] - 2026-05-05

### Add

- Animated button interactions with improved trackpad-tap support
- Side-panel transition animations for a smoother editing workflow

### Update

- Refined bottom sheet visual consistency across dialogs and panels
- Unified button architecture by splitting icon-only behavior from main button components
- Improved text tool input experience and overall UI consistency (colors and typography)
- Increased special effects intensity controls for stronger visual output

### Fix

- Eyedropper workflow usability improvements
- Undo/Redo control placement and behavior polish

## [1.6.4] - 2026-05-01

### Add

- Multi-stop gradient editing on canvas with draggable inner handles and stop-position support
- Side panel gradient stop percentage editing for inner stops with fixed endpoints (0% and 100%)
- Expanded widget/unit test coverage for gradient stop editor, selection overlay, import dialog, and window state helpers

### Fix

- Gradient stop ordering now swaps both stop colors and stop percentages consistently
- Adding or removing inner gradient stops now preserves existing stop percentages
- New stop insertion color now blends neighboring stop colors for smoother gradients
- Keyboard shortcut handling in text fields no longer blocks expected editing behavior
- Scenario test visual consistency updates for sky and mountain gradients

### Update

- Painting scenario helper flow now configures gradient stops through interactive side-panel behavior
- Project coverage increased to 86.0%

## [1.6.2] - 2026-04-29

### Add

- Most Recently Used (MRU) file list for quick access to recent artwork

### Fix

- Runtime crash on rotate
- Undo feature reliability in painting scenarios
- Code coverage improved to 85%

## [1.6.1] - 2026-04-28

### Fix

- AHEM font handling in text rendering and tests

### Refactor

- Unified app text styles for more consistent typography across the custom widget set
- Moved the former `material_free` widget implementations into `lib/widgets/`

## [1.6.0] - 2026-04-27

### Add

- HEIC image import support (all platforms)
- HEIC image export support (macOS via sips)
- Intensity of Special effects

## [1.5.1] - 2026-04-25

### Add

- Intensity of Special effects

### Refactor

- Clean up package dependencies
- iOS and macOS use SwiftPackageManager

## [1.5.0] - 2026-04-24

### Refactor

- Removed all `package:flutter/material.dart` and `package:flutter/cupertino.dart` dependencies from `lib/`
- Introduced custom zero-Material widget library (`lib/widgets/material_free/`) replacing all Material widgets
- Switched default UI font from Roboto to Inter (SIL OFL, screen-optimized, Apple SF Pro equivalent)

## [1.4.1] - 2026-04-23

### Refactor

- Unified SVG icon system into a single enhanced enum (`AppIcon`) and widget (`AppSvgIcon`)
- Removed redundant icon indirection layers (`AppIconAssets`, `AppToolIconAssets`, `AppAssets`)
- Removed deprecated files (`svg_icon.dart`, `app_svg_icon.dart`, `action_type_icon.dart`)
- Added `icon` property to `ActionType` enum, eliminating `iconFormatActionType` function
- Added `isSelected` parameter to `AppSvgIcon` for consistent selection state handling

## [1.4.0] - 2026-04-21

### Add

- Automatic recovery-restore flow for unsaved artwork at startup

### Fix

- ORA layer [visibility] attribute save/load

## [1.3.0] - 2026-04-17

### Add

- WEBP image format support
- Copy & Paste UX for touch devices
- Display dimensions when drawing the selection rectangle
- Haptic feedback on scale and rotate gestures
- SVG icons replacing Cupertino icons
- Video recording of test runs
- Test interaction overlay with tap target visualization

### Update

- Replaced integration tests with unit tests
- Use structured logging instead of debugPrint
- Use Roboto font in test runs for consistency
- Node.js 24 and Flutter 3.41.7

### Fix

- Crash when flipping canvas with text objects
- Crash when rotating canvas with text objects
- TIF export
- Hardcoded flip action names now use localized strings

### Remove

- cupertino_icons dependency

## [1.2.0] - 2026-04-10

### Add

- Scale, Rotate, and Transform controls directly on the selection overlay
- Live scale and rotation feedback during selection and transform edits
- A dedicated transform workflow that cleanly takes over from selection during active edits

### Update

- Shared overlay controls, localization, and tests for the new editing workflow

## [1.1.1] - 2025-11-01

### Add

- Comprehensive unit test suite for MagnifyingEyeDropper widget
- Integration test coverage with 53.2% overall code coverage
- VSCode test coverage configuration and HTML coverage reports
- Comprehensive documentation for all lib/*.dart files
- LCOV coverage file generation and merging utilities

### Update

- Enhanced documentation quality across entire codebase
- Improved test infrastructure with better mocking and async handling
- Updated VSCode settings for test coverage visualization
- Refactored test utilities for better maintainability

### Fix

- Resolved all failing unit tests (8 test files fixed)
- Fixed MagnifyingEyeDropper widget positioning issues
- Corrected test coverage file paths and configurations
- Improved error handling in test utilities

### Remove

- XCF (GIMP) file format support (experimental implementation removed)

## [1.1.0] - 2025-10-29

### Add

- Text feature
- Canvas rotation
- Tiff file support

### Update

- Remove dead code (getHueAndBrightness functions)
- Upgrade packages
- All deprecated SDK calls

### Fix

- Main canvas rendering
- Resizing of Canvas
- Canvas sizing feedback

## [1.0.6] - 2025-06-03

### Update - Flutter 3.35.7

## [1.0.5] - 2025-03-26

### Add

- Color-EyeDrop feature

## [1.0.4] - 2025-03-20

### Update

- Better experience on mobile phone

## [1.0.3] - 2025-03-05

### Add

- Linear Gradient and Radial Gradient fill

## [1.0.2] - 2025-03-02

### Add

- Crop

## [1.0.1] - 2025-02-28

### Update

- Flutter version: ">=3.29.0"
  
## [1.0.0] - 2025-02-28

### Add

- First release
