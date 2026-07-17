package com.kimjot.project

import android.Manifest
import android.app.Activity
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private lateinit var downloadManager: DownloadManager
    private var pendingGalleryPermissionResult: MethodChannel.Result? = null
    private var pendingFolderPickResult: MethodChannel.Result? = null
    private var pendingAudioPermissionResult: MethodChannel.Result? = null
    private var audioRecorder: MediaRecorder? = null
    private var audioRecordingPath: String? = null
    private var autoSyncOpenRequested = false
    private var galleryChannel: MethodChannel? = null
    private var updateReceiverRegistered = false
    private var waitingForInstallPermission = false
    private var installerLaunched = false
    private val updateDownloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
            val completedId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (completedId == pendingUpdateDownloadId()) {
                installPendingUpdate()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        ContextCompat.registerReceiver(
            this,
            updateDownloadReceiver,
            IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
            ContextCompat.RECEIVER_EXPORTED
        )
        updateReceiverRegistered = true
        resumePendingUpdate()
        captureAutoSyncOpenRequest(intent)
    }

    override fun onResume() {
        super.onResume()
        if (waitingForInstallPermission && canInstallUnknownApps()) {
            waitingForInstallPermission = false
            installerLaunched = false
            installPendingUpdate()
        }
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledVersion" -> result.success(installedVersion())
                "downloadAndInstallUpdate" -> downloadAndInstallUpdate(
                    call.argument<String>("apkUrl"),
                    call.argument<Number>("targetVersionCode")?.toLong() ?: 0L,
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun installedVersion(): Map<String, Any> {
        val packageInfo = packageManager.getPackageInfo(packageName, 0)
        val versionCode = installedVersionCode(packageInfo)
        return mapOf<String, Any>(
            "versionCode" to versionCode,
            "versionName" to (packageInfo.versionName ?: "")
        )
    }

    @Suppress("DEPRECATION")
    private fun installedVersionCode(): Long {
        return installedVersionCode(packageManager.getPackageInfo(packageName, 0))
    }

    @Suppress("DEPRECATION")
    private fun installedVersionCode(packageInfo: android.content.pm.PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
    }

    private fun downloadAndInstallUpdate(
        apkUrl: String?,
        targetVersionCode: Long,
        result: MethodChannel.Result
    ) {
        val uri = apkUrl?.let(Uri::parse)
        if (uri == null || uri.scheme != "https" || targetVersionCode <= 0L) {
            result.success(false)
            return
        }

        val preferences = updatePreferences()
        val pendingId = pendingUpdateDownloadId()
        val pendingTarget = preferences.getLong(PREF_UPDATE_TARGET_VERSION, 0L)
        val pendingUrl = preferences.getString(PREF_UPDATE_URL, null)
        if (pendingId > 0L && pendingTarget == targetVersionCode && pendingUrl == apkUrl) {
            when (downloadStatus(pendingId)) {
                DownloadManager.STATUS_SUCCESSFUL -> {
                    installerLaunched = false
                    result.success(installPendingUpdate())
                }
                DownloadManager.STATUS_PENDING,
                DownloadManager.STATUS_RUNNING,
                DownloadManager.STATUS_PAUSED -> {
                    result.success(true)
                }
                else -> clearPendingUpdate(removeDownload = true)
            }
            if (pendingUpdateDownloadId() > 0L) return
        } else if (pendingId > 0L) {
            clearPendingUpdate(removeDownload = true)
        }

        try {
            val request = DownloadManager.Request(uri)
                .setTitle("Kimjod ${targetVersionCode}")
                .setDescription("Downloading the required app update")
                .setMimeType(APK_MIME_TYPE)
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
                )
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(false)
                .setDestinationInExternalFilesDir(
                    this,
                    Environment.DIRECTORY_DOWNLOADS,
                    "kimjod-update-$targetVersionCode-${System.currentTimeMillis()}.apk"
                )
            val downloadId = downloadManager.enqueue(request)
            preferences.edit()
                .putLong(PREF_UPDATE_DOWNLOAD_ID, downloadId)
                .putLong(PREF_UPDATE_TARGET_VERSION, targetVersionCode)
                .putString(PREF_UPDATE_URL, apkUrl)
                .apply()
            result.success(true)
        } catch (_: Exception) {
            clearPendingUpdate(removeDownload = false)
            result.success(false)
        }
    }

    private fun resumePendingUpdate() {
        val pendingId = pendingUpdateDownloadId()
        if (pendingId <= 0L) return
        val targetVersion = updatePreferences().getLong(PREF_UPDATE_TARGET_VERSION, 0L)
        if (targetVersion > 0L && installedVersionCode() >= targetVersion) {
            clearPendingUpdate(removeDownload = true)
            return
        }
        if (downloadStatus(pendingId) == DownloadManager.STATUS_SUCCESSFUL) {
            installPendingUpdate()
        }
    }

    private fun installPendingUpdate(): Boolean {
        val downloadId = pendingUpdateDownloadId()
        if (downloadId <= 0L ||
            downloadStatus(downloadId) != DownloadManager.STATUS_SUCCESSFUL
        ) {
            return false
        }
        if (!canInstallUnknownApps()) {
            waitingForInstallPermission = true
            return openUnknownAppSourcesSettings()
        }
        if (installerLaunched) return true

        val apkUri = downloadManager.getUriForDownloadedFile(downloadId) ?: return false
        return try {
            installerLaunched = true
            startActivity(
                Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                    data = apkUri
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            )
            true
        } catch (_: Exception) {
            installerLaunched = false
            false
        }
    }

    private fun canInstallUnknownApps(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
    }

    private fun openUnknownAppSourcesSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun downloadStatus(downloadId: Long): Int? {
        return downloadManager.query(
            DownloadManager.Query().setFilterById(downloadId)
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
        }
    }

    private fun pendingUpdateDownloadId(): Long {
        return updatePreferences().getLong(PREF_UPDATE_DOWNLOAD_ID, -1L)
    }

    private fun updatePreferences() = getSharedPreferences(UPDATE_PREFS, MODE_PRIVATE)

    private fun clearPendingUpdate(removeDownload: Boolean) {
        val downloadId = pendingUpdateDownloadId()
        if (removeDownload && downloadId > 0L) {
            downloadManager.remove(downloadId)
        }
        updatePreferences().edit().clear().apply()
        waitingForInstallPermission = false
        installerLaunched = false
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
        if (updateReceiverRegistered) {
            unregisterReceiver(updateDownloadReceiver)
            updateReceiverRegistered = false
        }
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
        private const val APP_UPDATE_CHANNEL = "kimjod/app_update"
        private const val UPDATE_PREFS = "kimjod_app_update"
        private const val PREF_UPDATE_DOWNLOAD_ID = "download_id"
        private const val PREF_UPDATE_TARGET_VERSION = "target_version"
        private const val PREF_UPDATE_URL = "apk_url"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val MAX_FOLDER_IMAGES = 400
    }
}
