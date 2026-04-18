import Cocoa
import FlutterMacOS

private let fileOpenedMethod = "fileOpened"
private let mainWindowTitle = "fPaint"
private let openDocumentFirstIndex = 1

@main
class AppDelegate: FlutterAppDelegate {
    var fileChannel: FlutterMethodChannel?
    static var pendingFilePath: String?  // Temporarily store the file path

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
        NSLog("🚀 fPaint B - applicationDidFinishLaunching")

        // Set the app title
        mainFlutterWindow?.title = mainWindowTitle

        fileChannel = (mainFlutterWindow as? MainFlutterWindow)?.fileChannel
        
        // Send pending file path to Flutter if available.
        // Do NOT clear pendingFilePath here — the Dart engine may not be
        // listening yet. Let the Dart side clear it after consuming the file.
        if let pendingFilePath = AppDelegate.pendingFilePath {
            NSLog("📡 Sending pending file to Flutter (Dart may not be ready yet)")
            fileChannel?.invokeMethod(fileOpenedMethod, arguments: pendingFilePath)
        } else {
            NSLog("⚠️ No pending file found at launch")
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
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

        if let channel = fileChannel {
            NSLog("📡 Sending file to Flutter immediately")
            channel.invokeMethod(fileOpenedMethod, arguments: path)
        } else {
            NSLog("⚠️ fileChannel is nil, storing file for later")
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
}
