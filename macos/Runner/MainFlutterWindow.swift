import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var hapticChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    hapticChannel = FlutterMethodChannel(
      name: "com.vteam.fpaint/haptic",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    hapticChannel?.setMethodCallHandler { (call, result) in
      if call.method == "hapticAlignment" {
        NSHapticFeedbackManager.defaultPerformer.perform(
          .alignment,
          performanceTime: .now
        )
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
