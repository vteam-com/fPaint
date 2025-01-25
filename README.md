
# FPaint

## Flutter Drawing App

A feature-rich drawing and painting application built with Flutter that allows users to create digital artwork on any platform iOS,Android,macOS,Windows,Linux, and Web.

## Features

- Free-hand drawing and sketching
- Multiple brush sizes and styles
- Color picker with custom color palette
- Undo/Redo functionality
- Save drawings to device gallery
- Clear canvas option
- Background color customization
- Responsive design for different screen sizes

## Getting Started

### Prerequisites

- Flutter SDK (2.0 or higher)
- Dart SDK
- Android Studio / VS Code
- iOS Simulator / Android Emulator

### Installation

1. Clone the repository

git clone <https://github.com/yourusername/flutter-drawing-app.git>

1. Navigate to project directory

cd flutter-drawing-app

1. Install dependencies

flutter pub get

1. Run the app

flutter run

## Usage

1. Launch the app
2. Select your preferred brush size and color
3. Start drawing on the canvas
4. Use the toolbar to:
   - Change colors
   - Adjust brush size
   - Undo/Redo actions
   - Clear canvas
   - Save your artwork

## Dependencies

- `flutter_colorpicker`: For color selection
- `path_provider`: For saving drawings locally
- `permission_handler`: For handling storage permissions
- `image_gallery_saver`: For saving to device gallery

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Contributors and maintainers
- Open source community

## Screenshots

[Add your app screenshots here]

## OpenRaster ORA file

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
