import Flutter
import UIKit
import UniformTypeIdentifiers

private let fileAccessPluginKey = "FpaintFileAccess"
private let fileChannelName = "com.vteam.fpaint/file"
private let clearPendingFileMethod = "clearPendingFile"
private let fileOpenedMethod = "fileOpened"
private let getOpenedFileBookmarkMethod = "getOpenedFileBookmark"
private let getPendingFileMethod = "getPendingFile"
private let pickDocumentInPlaceMethod = "pickDocumentInPlace"
private let releaseBookmarkMethod = "releaseBookmark"
private let resolveBookmarkMethod = "resolveBookmark"
private let writeFileCoordinatedMethod = "writeFileCoordinated"
private let argBookmark = "bookmark"
private let argPath = "path"
private let argSourcePath = "sourcePath"
private let argTargetPath = "targetPath"
private let errorBusy = "BUSY"
private let errorInvalidArgs = "INVALID_ARGS"
private let errorNoPresenter = "NO_PRESENTER"
private let errorPickFailed = "PICK_FAILED"
private let errorResolveFailed = "RESOLVE_FAILED"
private let errorWriteFailed = "WRITE_FAILED"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var fileAccessChannel: FileAccessChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: fileAccessPluginKey) {
      let channel = FileAccessChannel(messenger: registrar.messenger())
      registrar.addSceneDelegate(channel)
      fileAccessChannel = channel
    }
  }
}

/// Opens documents from the Files app in place and writes saves back to them.
///
/// The `file_picker` plugin imports a private copy of the picked file, so a save
/// never reaches the original in iCloud Drive, Synology Drive or any other File
/// Provider. This channel picks with `asCopy: false`, hands Flutter a bookmark
/// for the original, and saves through `NSFileCoordinator` so the provider
/// notices the change and syncs it.
///
/// Documents handed over by the Files app ("Open in fPaint", share sheet) arrive
/// through the scene delegate calls, are bookmarked the same way, and are
/// offered to Flutter as the pending file — the contract macOS uses.
final class FileAccessChannel: NSObject, UIDocumentPickerDelegate,
  UIAdaptivePresentationControllerDelegate, FlutterSceneLifeCycleDelegate
{
  private let channel: FlutterMethodChannel
  private var pendingPickResult: FlutterResult?
  /// A document the system asked the app to open, until Flutter consumes it.
  private var pendingFilePath: String?
  /// Bookmarks of documents the system opened in place, keyed by path.
  private var openedFileBookmarks: [String: String] = [:]
  /// Security-scoped URLs currently being accessed, keyed by path.
  private var activeScopedURLs: [String: URL] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: fileChannelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case pickDocumentInPlaceMethod:
      pickDocumentInPlace(result: result)
    case getPendingFileMethod:
      result(pendingFilePath)
    case clearPendingFileMethod:
      pendingFilePath = nil
      result(nil)
    case getOpenedFileBookmarkMethod:
      result((call.arguments as? String).flatMap { openedFileBookmarks[$0] })
    case resolveBookmarkMethod:
      resolveBookmark(call.arguments, result: result)
    case releaseBookmarkMethod:
      if let path = call.arguments as? String,
        let url = activeScopedURLs.removeValue(forKey: path)
      {
        url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    case writeFileCoordinatedMethod:
      writeFileCoordinated(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Picking

  private func pickDocumentInPlace(result: @escaping FlutterResult) {
    guard pendingPickResult == nil else {
      result(FlutterError(code: errorBusy, message: "A document picker is already open", details: nil))
      return
    }
    guard let presenter = FileAccessChannel.topViewController() else {
      result(FlutterError(code: errorNoPresenter, message: "No view controller to present from", details: nil))
      return
    }
    pendingPickResult = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    picker.presentationController?.delegate = self
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = takePendingPickResult() else {
      return
    }
    guard let url = urls.first else {
      result(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let response: Any
      switch FileAccessChannel.bookmarkInPlaceDocument(url) {
      case .success(let bookmark):
        response = [argPath: url.path, argBookmark: bookmark]
      case .failure(let error):
        response = FlutterError(code: errorPickFailed, message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async {
        result(response)
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    takePendingPickResult()?(nil)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    takePendingPickResult()?(nil)
  }

  private func takePendingPickResult() -> FlutterResult? {
    let result = pendingPickResult
    pendingPickResult = nil
    return result
  }

  /// Downloads [url] if its provider only holds a placeholder, then bookmarks
  /// it. Returns the base-64 bookmark.
  private static func bookmarkInPlaceDocument(_ url: URL) -> Result<String, Error> {
    let isAccessing = url.startAccessingSecurityScopedResource()
    defer {
      if isAccessing {
        url.stopAccessingSecurityScopedResource()
      }
    }
    var coordinationError: NSError?
    var readError: Error?
    // A coordinated read makes the File Provider materialize the file locally.
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) {
      readURL in
      do {
        _ = try readURL.checkResourceIsReachable()
      } catch {
        readError = error
      }
    }
    if let error = coordinationError ?? readError {
      return .failure(error)
    }
    return Result {
      try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        .base64EncodedString()
    }
  }

  // MARK: - Documents opened by the system

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let context = connectionOptions?.urlContexts.first else {
      return false
    }
    receiveOpenedDocument(context)
    return true
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let context = URLContexts.first else {
      return false
    }
    receiveOpenedDocument(context)
    return true
  }

  /// Bookmarks a document opened in place (the original lives in a File
  /// Provider), then hands its path to Flutter. A document the system copied
  /// into the app's inbox needs no bookmark.
  private func receiveOpenedDocument(_ context: UIOpenURLContext) {
    let url = context.url
    guard url.isFileURL else {
      return
    }
    let opensInPlace = context.options.openInPlace
    DispatchQueue.global(qos: .userInitiated).async {
      let bookmark: String? = opensInPlace ? try? FileAccessChannel.bookmarkInPlaceDocument(url).get() : nil
      DispatchQueue.main.async {
        let path = url.path
        if let bookmark {
          self.openedFileBookmarks[path] = bookmark
        }
        // Kept until Flutter clears it: on a cold launch Dart asks for it once
        // its first frame is up, and may not be listening for the call below.
        self.pendingFilePath = path
        self.channel.invokeMethod(fileOpenedMethod, arguments: path)
      }
    }
  }

  // MARK: - Bookmarks

  private func resolveBookmark(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let base64 = arguments as? String, let data = Data(base64Encoded: base64) else {
      result(FlutterError(code: errorInvalidArgs, message: "Expected base64 bookmark string", details: nil))
      return
    }
    var isStale = false
    do {
      let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
      _ = url.startAccessingSecurityScopedResource()
      activeScopedURLs[url.path] = url
      result(url.path)
    } catch {
      result(FlutterError(code: errorResolveFailed, message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - Saving

  private func writeFileCoordinated(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let arguments = arguments as? [String: Any],
      let targetPath = arguments[argTargetPath] as? String,
      let sourcePath = arguments[argSourcePath] as? String
    else {
      result(FlutterError(code: errorInvalidArgs, message: "Expected target and source paths", details: nil))
      return
    }
    let targetURL = activeScopedURLs[targetPath] ?? URL(fileURLWithPath: targetPath)
    let sourceURL = URL(fileURLWithPath: sourcePath)
    DispatchQueue.global(qos: .userInitiated).async {
      let error = FileAccessChannel.copyCoordinated(from: sourceURL, to: targetURL)
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: errorWriteFailed, message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }

  /// Overwrites [targetURL] with [sourceURL]'s bytes inside a coordinated
  /// write, so the owning File Provider is told about the change and uploads
  /// it. The write is in place: the single-file access grant does not allow
  /// creating the sibling temp file an atomic write needs.
  private static func copyCoordinated(from sourceURL: URL, to targetURL: URL) -> Error? {
    var coordinationError: NSError?
    var writeError: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: targetURL, options: .forReplacing, error: &coordinationError
    ) { writeURL in
      do {
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: writeURL)
      } catch {
        writeError = error
      }
    }
    return coordinationError ?? writeError
  }

  // MARK: - Presentation

  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
