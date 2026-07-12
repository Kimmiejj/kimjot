package com.kimjot.project

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingGalleryPermissionResult: MethodChannel.Result? = null
    private var pendingFolderPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GALLERY_PERMISSION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestGalleryAccess" -> requestGalleryAccess(result)
                "pickImageFolder" -> pickImageFolder(result)
                else -> result.notImplemented()
            }
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
            val copiedImages = copyImagesFromTree(treeUri)
            result?.success(copiedImages)
        } catch (error: Exception) {
            result?.error("folder_read_failed", error.message, null)
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

        if (requestCode != GALLERY_PERMISSION_REQUEST_CODE) {
            return
        }

        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        pendingGalleryPermissionResult?.success(granted)
        pendingGalleryPermissionResult = null
    }

    companion object {
        private const val GALLERY_PERMISSION_CHANNEL = "kimjod/gallery_permission"
        private const val GALLERY_PERMISSION_REQUEST_CODE = 7301
        private const val FOLDER_PICK_REQUEST_CODE = 7302
        private const val MAX_FOLDER_IMAGES = 400
    }
}
