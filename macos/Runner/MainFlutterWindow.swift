import Cocoa
import FlutterMacOS

private let clearPendingFileMethod = "clearPendingFile"
private let fileChannelName = "com.vteam.fpaint/file"
private let getPendingFileMethod = "getPendingFile"
private let hapticChannelMethod = "hapticAlignment"
private let hapticChannelName = "com.vteam.fpaint/haptic"

class MainFlutterWindow: NSWindow {
  var fileChannel: FlutterMethodChannel?
  private var hapticChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    fileChannel = FlutterMethodChannel(
      name: fileChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    fileChannel?.setMethodCallHandler { (call, result) in
      if call.method == getPendingFileMethod {
        result(AppDelegate.pendingFilePath)
      } else if call.method == clearPendingFileMethod {
        AppDelegate.pendingFilePath = nil
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    hapticChannel = FlutterMethodChannel(
      name: hapticChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    hapticChannel?.setMethodCallHandler { (call, result) in
      if call.method == hapticChannelMethod {
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
