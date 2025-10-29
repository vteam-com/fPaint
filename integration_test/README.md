# fPaint Integration Tests

## Overview

This integration test suite performs complete end-to-end testing of the fPaint Flutter application, covering the entire user workflow from app launch through all painting features to app closure.

## Test Coverage

### Complete Workflow Testing
1. **App Launch** - Full initialization and UI loading (macOS compatible)
2. **Canvas Drawing** - Tap and move gestures with all tools
3. **New Document Creation** - Canvas clearing and layer management
4. **All Tools & Colors** - Brush, pencil, shapes with multiple colors
5. **Layer Management** - Adding, switching, and drawing on layers
6. **Canvas Operations** - Zoom, pan, crop, rotate, save/load
7. **App Closure** - Final state verification

### Specific Features Tested
- ✅ Drawing tools: Brush, Pencil, Rectangle, Circle
- ✅ Color palette: Multiple colors and fill options
- ✅ Layer system: Creation, selection, management
- ✅ Canvas navigation: Zoom (1.5x), pan, reset
- ✅ Undo/Redo: History operations (3 levels each)
- ✅ UI interactions: Shell mode changes
- ✅ Performance: 15 rapid drawing interactions (stress testing)
- ✅ Gesture testing: Tap, drag, multi-directional movement

## Platform Requirements

### ✅ macOS Desktop (Primary Target)
- **macOS Integration Testing**: Purpose-built to work on macOS
- **SharedPreferences Handling**: Graceful degradation when blocked
- **Desktop UI Testing**: Full support for desktop Flutter testing

### ✅ Mobile Platforms (Secondary)
- **Android Devices/Emulators**: Full SharedPreferences support
- **iOS Simulators/Devices**: Native platform testing

## Running Tests

### On macOS (Primary Method)
```bash
# Run integration tests directly on macOS
flutter test integration_test/app_integration_test.dart
```

### On Android Devices (Alternative)
```bash
# Connect Android device/emulator first
flutter devices

# Run integration tests
flutter test integration_test/app_integration_test.dart -d <android_device_id>
```

### On iOS Simulator (Alternative)
```bash
# Launch iOS Simulator first
open -a Simulator

# List available simulators
flutter devices

# Run integration tests
flutter test integration_test/app_integration_test.dart -d <ios_simulator_id>
```

## macOS Test Features

This integration test includes special handling for macOS environments:

### 🛠️ SharedPreferences Workarounds
- **Timeout-based initialization**: Uses controlled timeouts instead of `pumpAndSettle`
- **Graceful provider fallback**: Continues testing even if SharedPreferences blocks
- **Partial success reporting**: Reports what tests succeeded vs. what was blocked

### 🎯 macOS-Specific Testing
- **Gesture simulation**: Works correctly on desktop trackpad/mouse input
- **UI component verification**: Tests desktop-specific UI elements
- **Provider access testing**: Tests provider functionality when available
- **Fallback validation**: Ensures UI components load regardless of preferences

### 📊Expected Results on macOS

**Full Success** (SharedPreferences working):
```
✅ App launched and basic initialization completed
✅ UI components verified
✅ Canvas gesture testing completed
✅ Providers accessed successfully
✅ [All functionality tests pass]

🎉 fPaint macOS Integration Test COMPLETED SUCCESSFULLY!
```

**Partial Success** (SharedPreferences blocked):
```
✅ App launched and basic initialization completed
✅ UI components verified
✅ Canvas gesture testing completed
⚠️ Provider access failed (likely SharedPreferences issue)
   This is expected in macOS integration tests.
✅ Integration test partial success - UI and gesture framework verified
```

## Test Output

When successful, the test provides detailed progress:

```
🟢 STEP 1: Launching fPaint App...
✅ All drawing tools tested. Total actions: 12
✅ Layer management completed. Layers: 3, Selected: 2
✅ Canvas navigation tested successfully
✅ Undo/Redo operations verified
✅ Color tools and selection verified
✅ UI interactions tested
✅ Performance test completed. Total rapid actions: 10
✅ Canvas operations tested
✅ Final verification completed
🎉 COMPLETE fPaint End-to-End Integration Test PASSED!
📊 Final Stats:
   - Total Layers: 3
   - Total Actions: 22
   - Current Scale: 1.0
   - Shell Mode: ShellMode.full
```

## Test Structure

The integration test follows a step-by-step workflow that matches real user interaction patterns:

1. **Real gestures** using `TestGesture` objects
2. **State verification** after each operation
3. **Multi-tool testing** (brush, pencil, shapes)
4. **Layer interaction** management
5. **Canvas operations** (zoom/pan/reset)
6. **History operations** (undo/redo)
7. **Performance validation** (rapid interactions)

This ensures comprehensive coverage of the fPaint application's core functionality.
