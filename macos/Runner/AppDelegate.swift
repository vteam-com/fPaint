import Cocoa
import FlutterMacOS

private let editRedoMethod = "redo"
private let editUndoMethod = "undo"
private let fileOpenedMethod = "fileOpened"
private let fallbackWindowHeight: CGFloat = 900
private let fallbackWindowWidth: CGFloat = 1280
private let mainWindowTitle = "fPaint"
private let minimumVisibleWindowDimension: CGFloat = 100
private let openDocumentFirstIndex = 1

@main
class AppDelegate: FlutterAppDelegate {
    static var pendingFilePath: String?  // Temporarily store the file path

    private var liveEditChannel: FlutterMethodChannel? {
        return (mainFlutterWindow as? MainFlutterWindow)?.editChannel
    }

    private var liveFileChannel: FlutterMethodChannel? {
        return (mainFlutterWindow as? MainFlutterWindow)?.fileChannel
    }

    @IBAction func appUndo(_ sender: Any?) {
        liveEditChannel?.invokeMethod(editUndoMethod, arguments: nil)
    }

    @IBAction func appRedo(_ sender: Any?) {
        liveEditChannel?.invokeMethod(editRedoMethod, arguments: nil)
    }

    override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        handleOpenedFile(filename)
        return true
    }

    override func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        handleOpenedFile(filename)
        sender.reply(toOpenOrPrint: .success)
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        super.applicationDidFinishLaunching(notification)

        // Aggressive window setup: the XIB window may have 0x0 frame, so initialize it immediately
        let window = resolveMainWindow()
        window.title = mainWindowTitle
        
        // Force minimum visible size and center
        if window.frame.width < fallbackWindowWidth || window.frame.height < fallbackWindowHeight {
            window.setFrame(
                NSRect(x: 0, y: 0, width: fallbackWindowWidth, height: fallbackWindowHeight),
                display: true
            )
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Send pending file path to Flutter if available.
        // Do NOT clear pendingFilePath here — the Dart engine may not be
        // listening yet. Let the Dart side clear it after consuming the file.
        if let pendingFilePath = AppDelegate.pendingFilePath {
            if let channel = liveFileChannel {
                channel.invokeMethod(fileOpenedMethod, arguments: pendingFilePath)
            }
        }
    }

    override func applicationDidBecomeActive(_ notification: Notification) {
        super.applicationDidBecomeActive(notification)
        ensureMainWindowVisible(forceCenterIfOffScreen: false)
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ensureMainWindowVisible(forceCenterIfOffScreen: false)
        return true
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    override func applicationWillFinishLaunching(_ notification: Notification) {
        super.applicationWillFinishLaunching(notification)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        NSLog("🚀 fPaint handleOpenDocumentsEvent")

        guard let documentList = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            return
        }

        guard documentList.numberOfItems >= openDocumentFirstIndex else {
            return
        }

        for index in openDocumentFirstIndex...documentList.numberOfItems {
            guard let documentDescriptor = documentList.atIndex(index) else {
                continue
            }

            guard let path = filePath(from: documentDescriptor) else {
                continue
            }

            handleOpenedFile(path)
            return
        }
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        NSLog("🚀 fpaint 4 handleURLEvent")
        
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
            NSLog("🚀 fpaint 4 handleURLEvent \(urlString)")
            if let url = URL(string: urlString), url.isFileURL {
                handleOpenedFile(url.path)
                return
            }

            handleOpenedFile(urlString)
        }
    }

    private func handleOpenedFile(_ path: String) {
        NSLog("📂 openFile called with: \(path)")

        AppDelegate.pendingFilePath = path

        if let channel = liveFileChannel {
            NSLog("📡 Sending file to Flutter immediately")
            channel.invokeMethod(fileOpenedMethod, arguments: path)
        } else {
            NSLog("⚠️ No live Flutter file channel, storing file for later")
        }
    }

    private func filePath(from descriptor: NSAppleEventDescriptor) -> String? {
        if let rawValue = descriptor.stringValue {
            if let url = URL(string: rawValue), url.isFileURL {
                return url.path
            }

            return rawValue
        }

        guard let fileURLDescriptor = descriptor.coerce(toDescriptorType: DescType(typeFileURL)),
              let rawFileURL = fileURLDescriptor.stringValue,
              let url = URL(string: rawFileURL),
              url.isFileURL else {
            return nil
        }

        return url.path
    }

    private func ensureMainWindowVisible(forceCenterIfOffScreen: Bool) {
        let window = resolveMainWindow()

        if window.frame.width < minimumVisibleWindowDimension ||
            window.frame.height < minimumVisibleWindowDimension {
            window.setContentSize(NSSize(width: fallbackWindowWidth, height: fallbackWindowHeight))
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        if forceCenterIfOffScreen, isWindowOffScreen(window) {
            window.center()
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func resolveMainWindow() -> MainFlutterWindow {
        if let existingWindow = mainFlutterWindow as? MainFlutterWindow {
            return existingWindow
        }

        if let existingWindow = NSApp.windows.first as? MainFlutterWindow {
            mainFlutterWindow = existingWindow
            existingWindow.configureFlutterContentIfNeeded()
            return existingWindow
        }

        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let fallbackWindow = MainFlutterWindow(
            contentRect: NSRect(x: 0, y: 0, width: fallbackWindowWidth, height: fallbackWindowHeight),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        fallbackWindow.title = mainWindowTitle
        fallbackWindow.center()
        fallbackWindow.configureFlutterContentIfNeeded()
        mainFlutterWindow = fallbackWindow
        return fallbackWindow
    }

    private func isWindowOffScreen(_ window: NSWindow) -> Bool {
        let frame = window.frame

        for screen in NSScreen.screens {
            if screen.visibleFrame.intersects(frame) {
                return false
            }
        }

        return true
    }
}
