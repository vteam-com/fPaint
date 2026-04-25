<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

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
