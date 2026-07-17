package com.kimjot.project

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var pendingGalleryPermissionResult: MethodChannel.Result? = null
    private var pendingFolderPickResult: MethodChannel.Result? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var audioRecorder: MediaRecorder? = null
    private var audioRecordingPath: String? = null
    private var autoSyncOpenRequested = false
    private var galleryChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureAutoSyncOpenRequest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureAutoSyncOpenRequest(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        galleryChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GALLERY_PERMISSION_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestGalleryAccess" -> requestGalleryAccess(result)
                    "pickImageFolder" -> pickImageFolder(result)
                    "scanAutoSyncFolderNow" -> scanAutoSyncFolderNow(result)
                    "acknowledgeAutoSyncImages" -> {
                        val paths = call.argument<List<String>>("paths").orEmpty()
                        AutoSlipSync.acknowledgeImages(this, paths)
                        result.success(true)
                    }
                    "takeAutoSyncOpenRequest" -> {
                        val requested = autoSyncOpenRequested
                        autoSyncOpenRequested = false
                        result.success(requested)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> startAudioRecording(result)
                "stopRecording" -> stopAudioRecording(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioRecording(result: MethodChannel.Result) {
        if (audioRecorder != null || pendingAudioPermissionResult != null) {
            result.error("recording_busy", "Audio recording is already active", null)
            return
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingAudioPermissionResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                AUDIO_PERMISSION_REQUEST_CODE
            )
            return
        }

        beginAudioRecording(result)
    }

    private fun beginAudioRecording(result: MethodChannel.Result) {
        val outputFile = File(cacheDir, "kimjod_voice_${System.currentTimeMillis()}.m4a")
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        try {
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioEncodingBitRate(96_000)
            recorder.setOutputFile(outputFile.absolutePath)
            recorder.prepare()
            recorder.start()
            audioRecorder = recorder
            audioRecordingPath = outputFile.absolutePath
            result.success(true)
        } catch (error: Exception) {
            recorder.release()
            outputFile.delete()
            result.error("recording_failed", error.message, null)
        }
    }

    private fun stopAudioRecording(result: MethodChannel.Result) {
        val recorder = audioRecorder
        val path = audioRecordingPath
        if (recorder == null || path == null) {
            result.success(null)
            return
        }

        audioRecorder = null
        audioRecordingPath = null
        try {
            recorder.stop()
            result.success(path)
        } catch (_: RuntimeException) {
            File(path).delete()
            result.success(null)
        } finally {
            recorder.release()
        }
    }

    private fun requestGalleryAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }

        val permission = galleryPermission()
        if (ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        if (pendingGalleryPermissionResult != null) {
            result.success(false)
            return
        }

        pendingGalleryPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(permission),
            GALLERY_PERMISSION_REQUEST_CODE
        )
    }

    private fun pickImageFolder(result: MethodChannel.Result) {
        if (pendingFolderPickResult != null) {
            result.success(emptyList<String>())
            return
        }

        pendingFolderPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, FOLDER_PICK_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != FOLDER_PICK_REQUEST_CODE) {
            return
        }

        val result = pendingFolderPickResult
        pendingFolderPickResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(emptyList<String>())
            return
        }

        val treeUri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // Some document providers do not offer persistable permissions.
        }

        try {
            AutoSlipSync.configureFolder(this, treeUri)
            val copiedImages = copyImagesFromTree(treeUri)
            result?.success(copiedImages)
        } catch (error: Exception) {
            result?.error("folder_read_failed", error.message, null)
        }
    }

    private fun scanAutoSyncFolderNow(result: MethodChannel.Result) {
        Thread {
            val paths = try {
                AutoSlipSync.scanAndQueue(this, showNotification = true)
            } catch (_: Exception) {
                AutoSlipSync.pendingImages(this)
            }
            runOnUiThread { result.success(paths) }
        }.start()
    }

    private fun captureAutoSyncOpenRequest(intent: Intent?) {
        if (intent?.getBooleanExtra(AutoSlipSync.OPEN_REQUEST_EXTRA, false) == true) {
            autoSyncOpenRequested = true
            intent.removeExtra(AutoSlipSync.OPEN_REQUEST_EXTRA)
            galleryChannel?.invokeMethod("autoSyncOpenRequested", null)
        }
    }

    private fun copyImagesFromTree(treeUri: Uri): List<String> {
        val outputDir = File(cacheDir, "kimjod_slip_import").apply {
            mkdirs()
        }
        val copiedPaths = mutableListOf<String>()
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)

        copyImagesFromDocument(treeUri, rootDocumentId, outputDir, copiedPaths)
        return copiedPaths
    }

    private fun copyImagesFromDocument(
        treeUri: Uri,
        documentId: String,
        outputDir: File,
        copiedPaths: MutableList<String>
    ) {
        if (copiedPaths.size >= MAX_FOLDER_IMAGES) {
            return
        }

        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            documentId
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )

        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )
            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )

            while (cursor.moveToNext() && copiedPaths.size < MAX_FOLDER_IMAGES) {
                val childId = cursor.getString(idIndex)
                val displayName = cursor.getString(nameIndex) ?: "image"
                val mimeType = cursor.getString(mimeIndex) ?: ""

                if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                    copyImagesFromDocument(treeUri, childId, outputDir, copiedPaths)
                    continue
                }

                if (!mimeType.startsWith("image/")) {
                    continue
                }

                val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                val safeName = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                val outputFile = File(
                    outputDir,
                    "${System.currentTimeMillis()}_${copiedPaths.size}_$safeName"
                )

                contentResolver.openInputStream(documentUri)?.use { input ->
                    outputFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }

                copiedPaths.add(outputFile.absolutePath)
            }
        }
    }

    private fun galleryPermission(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == AUDIO_PERMISSION_REQUEST_CODE) {
            val result = pendingAudioPermissionResult
            pendingAudioPermissionResult = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                if (result != null) beginAudioRecording(result)
            } else {
                result?.success(false)
            }
            return
        }

        if (requestCode != GALLERY_PERMISSION_REQUEST_CODE) return

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingGalleryPermissionResult?.success(granted)
        pendingGalleryPermissionResult = null
    }

    override fun onDestroy() {
        val recorder = audioRecorder
        audioRecorder = null
        audioRecordingPath?.let { File(it).delete() }
        audioRecordingPath = null
        try {
            recorder?.stop()
        } catch (_: RuntimeException) {
            // A very short interrupted recording may not contain enough data.
        } finally {
            recorder?.release()
        }
        super.onDestroy()
    }

    companion object {
        private const val GALLERY_PERMISSION_CHANNEL = "kimjod/gallery_permission"
        private const val GALLERY_PERMISSION_REQUEST_CODE = 7301
        private const val FOLDER_PICK_REQUEST_CODE = 7302
        private const val AUDIO_PERMISSION_REQUEST_CODE = 7304
        private const val DEVICE_AUDIO_CHANNEL = "kimjod/device_audio"
        private const val MAX_FOLDER_IMAGES = 400
    }
}
