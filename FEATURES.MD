# fPaint Features

This document lists the features currently available in fPaint.

## User Features (Quick List)

- Draw with freehand, line, rectangle, and circle tools
- Add and style text on the canvas
- Fill areas with solid, linear gradient, or radial gradient colors
- Use rectangle, circle, lasso, and magic wand selections
- Duplicate a selected region quickly without overwriting existing clipboard contents
- Scale, rotate, and transform selected content
- Work with multiple layers, including visibility, opacity, rename, and merge
- Resize/crop the canvas with anchor positioning
- Save and export artwork as ORA, PNG, JPEG, TIFF, and WEBP
- Recover unsaved work automatically when restarting the app
- Use the app across iOS, Android, macOS, Windows, Linux, and Web

## Detailed Feature Inventory

## Platform and App Experience

- Cross-platform app built with one Flutter codebase
- Runs on iOS, Android, macOS, Windows, Linux, and Web
- Touch, mouse, and stylus-friendly interaction model
- Localized UI support (via Flutter localization)
- Automatic recovery/restore flow for unsaved artwork on startup

## Drawing and Painting Tools

- Freehand painting workflow with adjustable brush settings
- Line tool
- Rectangle tool
- Circle tool
- Text tool
- Fill tool

## Fill Modes and Color Workflows

- Solid fill
- Linear gradient fill
- Radial gradient fill
- Color picker workflows, including eyedropper support
- Palette/color panel workflows for brush, fill, and text colors

## Selection and Editing

- Rectangle selection
- Circle selection
- Lasso selection
- Magic Wand selection
- Selection math modes: replace, add, remove, invert
- Region erase operations based on active selection
- One-step Duplicate action for active selections
- Selection-aware actions: copy, cut, duplicate, and effects auto-select the entire active layer when no selection exists (see [SCENARIO_SELECTION_CONTEXT](scenarios/SCENARIO_SELECTION_CONTEXT.md))

## Transform Capabilities

- Dedicated transform tool/workflow
- Selection overlay controls for scale and rotation
- Drag handles for selection deformation/reshaping
- Live scale and rotation feedback during edits
- Canvas rotation
- Canvas flip support

## Layers

- Multi-layer editing workflow
- Add, rename, switch, and remove layers
- Merge layers
- Layer visibility control
- Layer opacity control

## Canvas Management

- Canvas resize/crop via canvas settings
- Resize anchor positioning support
- Canvas size feedback during edits

## File Handling and Formats

- OpenRaster (ORA) support
- PNG support
- JPEG support
- TIFF support
- WEBP support
- Save/export workflows through app UI
- Correct save/load handling for layer visibility in ORA

## Interaction and UX Enhancements

- Copy and paste UX improvements for touch devices
- Keyboard shortcut for duplicate: Cmd+D (macOS), Ctrl+D (Windows/Linux)
- Haptic feedback on scale and rotate gestures
- Display dimensions while drawing selection rectangles
- Updated icon set using SVG assets
- Effects (Blur, Sharpen, Pixelate, Grayscale, Noise, Soften, Vignette) accessible from the selector tool panel without requiring an active selection

## Quality and Testing Support (Project Capability)

- Comprehensive widget/unit test workflows for drawing and editing scenarios
- Test video recording support for interaction playback
- Test overlay visualization for tap targets
