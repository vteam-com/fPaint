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

    override func application(_ application: NSApplication, open urls: [URL]) {
        NSLog("🚀 fPaint A - application")
        
        for url in urls {
            NSLog("🚀 fPaint A fileOpened \(url.path)")
            AppDelegate.pendingFilePath = url.path
            fileChannel?.invokeMethod("fileOpened", arguments: url.path)
        }
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
        
        // Send pending file path to Flutter if available
        if let pendingFilePath = AppDelegate.pendingFilePath {
            NSLog("📡 Sending pending file to Flutter")
            fileChannel?.invokeMethod("fileOpened", arguments: pendingFilePath)
            AppDelegate.pendingFilePath = nil // Clear after sending
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
