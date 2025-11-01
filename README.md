# fPaint

## Free, Open-Source Raster Graphics Editor

**A community-driven Flutter app aiming to provide professional-grade drawing and painting tools that rival paid commercial software - completely free and open source.**

Built with Flutter for cross-platform excellence, fPaint empowers artists, designers, and creators with powerful raster graphics tools across iOS, Android, macOS, Windows, Linux, and Web from a single codebase.

## 🎯 Our Mission

To create a **free alternative to expensive commercial graphics software** through community collaboration. We believe great tools should be accessible to everyone, and Flutter's cross-platform capabilities make this vision possible.

## ✨ Features

- **Professional Drawing Tools** - Advanced brushes, pressure sensitivity, and precision controls
- **Layer Management** - Full layer system with blending modes, opacity, and organization
- **Selection Tools** - Magic Wand, lasso, rectangle, and advanced selection capabilities
- **Color Management** - Professional color picker with palettes, gradients, and color harmony
- **File Format Support** - PNG, JPEG, TIFF, OpenRaster (ORA), and more
- **Cross-Platform** - Consistent experience across all major platforms
- **Undo/Redo** - Robust history system for creative freedom
- **Responsive UI** - Optimized for touch, mouse, and stylus input

## 🚀 Join the Revolution

**This is more than an app - it's a movement.** We're building the future of free graphics software together. Whether you're a:

- **Flutter Developer** - Help us push the boundaries of what's possible with Flutter
- **Graphics Programmer** - Implement advanced algorithms and optimizations
- **UI/UX Designer** - Create intuitive interfaces that inspire creativity
- **Artist/Designer** - Provide feedback on tools and workflows
- **Tester** - Help ensure quality across all platforms
- **Documentation Writer** - Make our project accessible to newcomers

**Your contribution matters.** Every line of code, every bug report, every feature suggestion brings us closer to replacing paid commercial software with a truly free alternative.

## 💝 100% Free, No Ads, No Paywalls

Unlike commercial alternatives, fPaint will always remain completely free with:
- 🙅🏼 No ads or monetization
- 🙅🏼 No feature restrictions
- 🙅🏼 No premium tiers
- ✅ Full source code transparency
- ✅ Community-driven development
- ✅ Cross-platform availability

## 🗺️ Roadmap to Professional Graphics Software

We're building toward feature parity with commercial graphics editors. Current priorities include:

### Phase 1: Core Enhancement (Current)
- [x] Multi-layer system with blending modes
- [x] Advanced selection tools (Magic Wand, Lasso)
- [x] Professional color management
- [x] Multiple file format support
- [ ] **Advanced brush engines** (contributions needed!)
- [ ] **Text tool improvements** (contributions needed!)
- [ ] **Performance optimizations** (contributions needed!)

### Phase 2: Professional Features
- [ ] Non-destructive filters and effects
- [ ] Advanced typography and text-on-path
- [ ] CMYK color management
- [ ] Scripting/automation

**Your expertise in any of these areas would accelerate our progress tremendously!**

## Getting Started

### Prerequisites

- Flutter SDK (3.35.7 or higher)
- Dart SDK (3.9.2 or higher)
- Edit and build on macOS, Windows, or Linux
- IDE: VS Code or Android Studio
- iOS Simulator / Android Emulator (for mobile development)

### Installation

1. Clone the repository

    ```bash
    git clone https://github.com/vteam-com/fPaint.git
    ```

2. Navigate to the project directory

    ```bash
    cd fPaint
    ```

3. Install dependencies

    ```bash
    flutter pub get
    ```

4. Run the app

    ```bash
    flutter run
    ```

## Testing

### Integration Testing

fPaint includes comprehensive integration tests that demonstrate advanced painting features and multi-layer scene creation. The integration tests use human-like gestures to simulate real user interactions and create complete artwork scenes.

#### Running Integration Tests

To run the integration tests:

```bash
# Run all unit test
flutter test

# Run integration test
./tool/run_integration_test.sh
```

#### Test Features

The integration tests demonstrate:

- **Multi-layer scene creation**: Sky gradients, sun with radiating rays, land, houses, and fences
- **Advanced drawing tools**: Circles, rectangles, lines with human-like gesture simulation
- **Gradient fills**: Linear and radial gradients for backgrounds and effects
- **Layer management**: Creating, switching, and organizing artwork layers
- **Selection tools**: Circle selection for precise area targeting
- **Color management**: Dynamic color palette and fill operations

#### Test Helpers

The `integration_test/integration_helpers.dart` file provides reusable helper functions for:

- Human-like drawing gestures (circles, rectangles, lines)
- Layer management operations
- Gradient fill operations
- Color picker interactions
- UI element tapping and navigation

## Usage

1. Launch the app
2. Choose your preferred brush size and color
3. Start drawing on the canvas
4. Use the SidePanel to:
   - Change colors
   - Adjust brush size
   - Use advanced selection tools such as Magic Wand selection
   - Manage layers efficiently
   - Undo/Redo actions
   - Clear the canvas
   - Save your artwork

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on how to get started.

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing.

## Security

If you discover a security vulnerability, please see our [Security Policy](SECURITY.md).

## License

This project is licensed under the **MIT** License - see the [LICENSE](LICENSE) file for details.

## Screenshots

![fPaint Screenshot](fPaint.png)

## The OpenRaster (ORA) file format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<image xmlns:drawpile="http://paint.vteam.com/"
    xmlns:mypaint="http://mypaint.org/ns/openraster" w="800" h="800" version="0.0.6" xres="72" yres="72" drawpile:framerate="24">
    <stack>
        <layer src="data/layer-0103.png" x="134" y="91" opacity="1.0000" name="birds"/>
        <layer src="data/layer-0100.png" y="268" opacity="1.0000" name="Cloud"/>
        <layer src="data/layer-0101.png" y="579" opacity="1.0000" name="Dirt"/>
        <layer src="data/layer-0102.png" opacity="1.0000" name="sky"/>
        <layer name="Background" src="data/background.png" mypaint:background-tile="data/background-tile.png"/>
    </stack>
</image>
```

## Graph Dependencies

![Call Graph](graph.svg)

*How to generate the above graph. Run these commands on macOS .*

```bash
dart pub global activate lakos
brew install graphviz
./tool/graph.sh
```

Please contribute and report issues on the GitHub repository.
<https://github.com/vteam-com/fPaint>
