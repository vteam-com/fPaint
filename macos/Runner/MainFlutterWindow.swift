import Cocoa
import FlutterMacOS

private let clearPendingFileMethod = "clearPendingFile"
private let fileChannelName = "com.vteam.fpaint/file"
private let getPendingFileMethod = "getPendingFile"
private let hapticChannelMethod = "hapticAlignment"
private let hapticChannelName = "com.vteam.fpaint/haptic"
private let createBookmarkMethod = "createBookmark"
private let resolveBookmarkMethod = "resolveBookmark"
private let releaseBookmarkMethod = "releaseBookmark"

/// Tracks security-scoped URLs currently being accessed, keyed by path.
private var activeScopedURLs: [String: URL] = [:]

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
      } else if call.method == createBookmarkMethod {
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected path string", details: nil))
          return
        }
        let url = URL(fileURLWithPath: path)
        do {
          let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          )
          result(bookmarkData.base64EncodedString())
        } catch {
          result(FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil))
        }
      } else if call.method == resolveBookmarkMethod {
        guard let base64 = call.arguments as? String,
              let data = Data(base64Encoded: base64) else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected base64 bookmark string", details: nil))
          return
        }
        var isStale = false
        do {
          let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
          )
          url.startAccessingSecurityScopedResource()
          activeScopedURLs[url.path] = url
          result(url.path)
        } catch {
          result(FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }
      } else if call.method == releaseBookmarkMethod {
        guard let path = call.arguments as? String else {
          result(nil)
          return
        }
        if let url = activeScopedURLs.removeValue(forKey: path) {
          url.stopAccessingSecurityScopedResource()
        }
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
