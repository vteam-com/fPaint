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
private let releaseBookmarkMethod = "releaseBookmark"

/// Tracks security-scoped URLs currently being accessed, keyed by path.
private var activeScopedURLs: [String: URL] = [:]

class MainFlutterWindow: NSWindow {
  var editChannel: FlutterMethodChannel?
  var fileChannel: FlutterMethodChannel?
  private var hapticChannel: FlutterMethodChannel?

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
