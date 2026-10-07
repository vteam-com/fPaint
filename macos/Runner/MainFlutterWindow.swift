import Cocoa
import FlutterMacOS

private let clearPendingFileMethod = "clearPendingFile"
private let editChannelName = "com.vteam.fpaint/edit"
private let editRedoAlternateKeyEquivalent = "y"
private let editRedoMethod = "redo"
private let editShortcutModifierMask: NSEvent.ModifierFlags = [.command, .shift, .control, .option]
private let editShortcutRedoModifierMask: NSEvent.ModifierFlags = [.command, .shift]
private let editShortcutUndoModifierMask: NSEvent.ModifierFlags = [.command]
private let editUndoMethod = "undo"
private let editUndoRedoKeyEquivalent = "z"
private let fileChannelName = "com.vteam.fpaint/file"
private let getPendingFileMethod = "getPendingFile"
private let hapticChannelMethod = "hapticAlignment"
private let hapticChannelName = "com.vteam.fpaint/haptic"
private let createBookmarkMethod = "createBookmark"
private let replaceFileWithBackupMethod = "replaceFileWithBackup"
private let resolveBookmarkMethod = "resolveBookmark"
private let trackpadChannelName = "com.vteam.fpaint/trackpad"
private let trackpadPressureMethod = "pressure"
/// Force Touch stage of an ordinary click; stage 2 is the deeper force click.
private let trackpadClickStage = 1
/// Pressure reported once the press passes the click stage (force click).
private let trackpadFullPressure = 1.0
/// Pressure of the lightest held click.
private let trackpadNoPressure = 0.0
private let releaseBookmarkMethod = "releaseBookmark"

/// Tracks security-scoped URLs currently being accessed, keyed by path.
private var activeScopedURLs: [String: URL] = [:]

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  var editChannel: FlutterMethodChannel?
  var fileChannel: FlutterMethodChannel?
  private var hapticChannel: FlutterMethodChannel?
  private var trackpadChannel: FlutterMethodChannel?
  private var trackpadPressureMonitor: Any?

  /// Routes the red close button through the app's quit confirmation.
  ///
  /// `applicationShouldTerminateAfterLastWindowClosed` is true, so closing this
  /// window quits anyway. Closing first would tear down the Flutter view before
  /// the unsaved-changes dialog could be shown, so the close is refused here
  /// and termination is requested instead — the dialog then runs in a live
  /// window, and the approved quit closes the app.
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    NSApp.terminate(nil)
    return false
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if isTextEditingResponderActive == false,
      let editMethod = MainFlutterWindow.editMethod(forKeyEquivalentEvent: event),
      let editChannel
    {
      editChannel.invokeMethod(editMethod, arguments: nil)
      return true
    }

    return super.performKeyEquivalent(with: event)
  }

  override func awakeFromNib() {
    // CRITICAL: The XIB window has no frame defined, so it loads with 0 width.
    // Set a proper default frame immediately, before Flutter initialization.
    if frame.width < 100 || frame.height < 100 {
      setFrame(NSRect(x: 100, y: 100, width: 1280, height: 900), display: false)
      center()
    }
    
    delegate = self
    configureFlutterContentIfNeeded()
    super.awakeFromNib()
    
    // Make window visible immediately
    orderFront(nil)
    makeKey()
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func configureFlutterContentIfNeeded() {
    if contentViewController is FlutterViewController {
      return
    }

    let flutterViewController = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureChannels(with: flutterViewController)
    configureTrackpadPressure(with: flutterViewController)
  }

  private func configureChannels(with flutterViewController: FlutterViewController) {
    editChannel = FlutterMethodChannel(
      name: editChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

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
          result(
            FlutterError(code: "BOOKMARK_FAILED", message: error.localizedDescription, details: nil)
          )
        }
      } else if call.method == resolveBookmarkMethod {
        guard let base64 = call.arguments as? String,
          let data = Data(base64Encoded: base64)
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS", message: "Expected base64 bookmark string", details: nil))
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
          _ = url.startAccessingSecurityScopedResource()
          activeScopedURLs[url.path] = url
          result(url.path)
        } catch {
          result(
            FlutterError(code: "RESOLVE_FAILED", message: error.localizedDescription, details: nil))
        }
      } else if call.method == replaceFileWithBackupMethod {
        guard let arguments = call.arguments as? [String: Any],
          let targetPath = arguments["targetPath"] as? String,
          let replacementPath = arguments["replacementPath"] as? String,
          let backupFileName = arguments["backupFileName"] as? String
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS", message: "Expected target, replacement, and backup paths", details: nil))
          return
        }

        let targetURL = activeScopedURLs[targetPath] ?? URL(fileURLWithPath: targetPath)
        let replacementURL = URL(fileURLWithPath: replacementPath)

        do {
          _ = try FileManager.default.replaceItemAt(
            targetURL,
            withItemAt: replacementURL,
            backupItemName: backupFileName,
            options: [.withoutDeletingBackupItem]
          )
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "REPLACE_WITH_BACKUP_FAILED", message: error.localizedDescription, details: nil))
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
  }

  /// Forwards Force Touch trackpad pressure to Flutter, whose desktop embedder
  /// drops pointer pressure. Mouse-up also reports so a missed release never
  /// leaves a stale pressure behind for the next (possibly plain mouse) click.
  private func configureTrackpadPressure(with flutterViewController: FlutterViewController) {
    trackpadChannel = FlutterMethodChannel(
      name: trackpadChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    trackpadPressureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.pressure, .leftMouseUp]) {
      [weak self] event in
      if let self, event.window === self {
        self.trackpadChannel?.invokeMethod(
          trackpadPressureMethod,
          arguments: MainFlutterWindow.trackpadPressure(for: event)
        )
      }
      return event
    }
  }

  /// Normalized 0...1 pressure of a held trackpad click, or nil when the
  /// event is not a pressure event or the trackpad is no longer clicked.
  static func trackpadPressure(for event: NSEvent) -> Double? {
    guard event.type == .pressure, event.stage >= trackpadClickStage else {
      return nil
    }
    if event.stage > trackpadClickStage {
      return trackpadFullPressure
    }
    return min(max(Double(event.pressure), trackpadNoPressure), trackpadFullPressure)
  }

  static func editMethod(forKeyEquivalentEvent event: NSEvent) -> String? {
    guard event.type == .keyDown,
      let charactersIgnoringModifiers = event.charactersIgnoringModifiers?.lowercased()
    else {
      return nil
    }

    let modifierFlags = event.modifierFlags.intersection(editShortcutModifierMask)

    if charactersIgnoringModifiers == editUndoRedoKeyEquivalent {
      if modifierFlags == editShortcutUndoModifierMask {
        return editUndoMethod
      }

      if modifierFlags == editShortcutRedoModifierMask {
        return editRedoMethod
      }

      return nil
    }

    if charactersIgnoringModifiers == editRedoAlternateKeyEquivalent,
      modifierFlags == editShortcutUndoModifierMask
    {
      return editRedoMethod
    }

    return nil
  }

  private var isTextEditingResponderActive: Bool {
    firstResponder is NSTextView
  }
}
