package com.vteam.fpaint

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

private const val FILE_CHANNEL_NAME = "com.vteam.fpaint/file"
private const val GET_PENDING_FILE_METHOD = "getPendingFile"
private const val CLEAR_PENDING_FILE_METHOD = "clearPendingFile"
private const val FILE_OPENED_METHOD = "fileOpened"
private const val OPENED_FILES_DIRECTORY = "opened_files"
private const val FALLBACK_FILE_NAME = "image"
private const val EXTENSION_SEPARATOR = "."

/**
 * Hands documents that other apps open with fPaint ("Open with", Files,
 * e-mail attachments) to Flutter.
 *
 * Android delivers them as `content://` URIs that Dart cannot read, so each
 * one is copied into the app cache under its original display name (the
 * extension picks the decoder) and offered over the same file channel iOS and
 * macOS use: `getPendingFile` for the document that launched the app,
 * `fileOpened` for one that arrives while it is running.
 */
class MainActivity : FlutterActivity() {
    private val copyExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler: Handler = Handler(Looper.getMainLooper())
    private var fileChannel: MethodChannel? = null

    /** The copy of the document that launched the app, until Flutter consumes it. */
    private var pendingFile: Future<String?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                GET_PENDING_FILE_METHOD -> replyWithPendingFile(result)
                CLEAR_PENDING_FILE_METHOD -> {
                    pendingFile = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        fileChannel = channel
        pendingFile = copyViewIntentAsync(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = viewIntentUri(intent) ?: return
        copyExecutor.execute {
            val path = copyToCache(uri) ?: return@execute
            mainHandler.post { fileChannel?.invokeMethod(FILE_OPENED_METHOD, path) }
        }
    }

    override fun onDestroy() {
        copyExecutor.shutdown()
        super.onDestroy()
    }

    private fun replyWithPendingFile(result: MethodChannel.Result) {
        val copy = pendingFile
        if (copy == null) {
            result.success(null)
            return
        }
        copyExecutor.execute {
            val path = copy.get()
            mainHandler.post { result.success(path) }
        }
    }

    private fun copyViewIntentAsync(intent: Intent?): Future<String?>? {
        val uri = viewIntentUri(intent) ?: return null
        return copyExecutor.submit<String?> { copyToCache(uri) }
    }

    private fun viewIntentUri(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_VIEW) {
            return null
        }
        return intent.data
    }

    /**
     * Copies [uri] into the cache and returns the copy's path, or null when
     * the document cannot be read.
     */
    private fun copyToCache(uri: Uri): String? {
        if (uri.scheme == ContentResolver.SCHEME_FILE) {
            return uri.path
        }
        return try {
            val directory = File(cacheDir, OPENED_FILES_DIRECTORY)
            directory.mkdirs()
            val target = File(directory, displayNameOf(uri))
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            target.absolutePath
        } catch (error: Exception) {
            null
        }
    }

    /**
     * The document's file name without any directory part, falling back to a
     * generic name with the extension its MIME type implies.
     */
    private fun displayNameOf(uri: Uri): String {
        val queried = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        val name = queried?.let { File(it).name }
        if (!name.isNullOrBlank()) {
            return name
        }
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(contentResolver.getType(uri))
        return if (extension == null) FALLBACK_FILE_NAME else FALLBACK_FILE_NAME + EXTENSION_SEPARATOR + extension
    }
}
