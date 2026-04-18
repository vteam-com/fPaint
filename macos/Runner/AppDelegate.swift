import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var fileChannel: FlutterMethodChannel?
    static var pendingFilePath: String?  // Temporarily store the file path

    override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        NSLog("🚀 fPaint 1 - openFile")
        NSLog("📂 openFile called with: \(filename)")
        
        // Save the file path in a static variable for later use
        AppDelegate.pendingFilePath = filename

        // If the Flutter method channel is ready, send the file directly
        if let channel = fileChannel {
            NSLog("📡 Sending file to Flutter immediately")
            channel.invokeMethod("fileOpened", arguments: filename)
            AppDelegate.pendingFilePath = nil // Clear after sending
        } else {
            NSLog("⚠️ fileChannel is nil, storing file for later")
        }
        
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 fPaint B - applicationDidFinishLaunching")

        // Set the app title
        mainFlutterWindow?.title = "fPaint"

        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        fileChannel = FlutterMethodChannel(
            name: "com.vteam.fpaint/file",
            binaryMessenger: controller.engine.binaryMessenger
        )

        // Handle Dart-side queries for pending file path
        fileChannel?.setMethodCallHandler { (call, result) in
            if call.method == "getPendingFile" {
                result(AppDelegate.pendingFilePath)
                AppDelegate.pendingFilePath = nil
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Send pending file path to Flutter if available.
        // Do NOT clear pendingFilePath here — the Dart engine may not be
        // listening yet. Let the Dart side clear it via getPendingFile.
        if let pendingFilePath = AppDelegate.pendingFilePath {
            NSLog("📡 Sending pending file to Flutter (Dart may not be ready yet)")
            fileChannel?.invokeMethod("fileOpened", arguments: pendingFilePath)
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
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        NSLog("🚀 fpaint 4 handleURLEvent")
        
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue {
            NSLog("🚀 fpaint 4 handleURLEvent \(urlString)")
            fileChannel?.invokeMethod("fileOpened", arguments: urlString)
        }
    }
}
