package com.kimjot.project

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.io.File
import java.util.concurrent.TimeUnit

object AutoSlipSync {
    const val OPEN_REQUEST_EXTRA = "kimjod_open_auto_slip_sync"

    private const val PREFERENCES_NAME = "kimjod_auto_slip_sync"
    private const val FOLDER_URI_KEY = "folder_uri"
    private const val FOLDER_URIS_KEY = "folder_uris"
    private const val KNOWN_DOCUMENT_IDS_KEY = "known_document_ids"
    private const val PENDING_IMAGE_PATHS_KEY = "pending_image_paths"
    private const val PERIODIC_WORK_NAME = "kimjod_auto_slip_sync_periodic"
    private const val NOTIFICATION_CHANNEL_ID = "kimjod_auto_slip_sync"
    private const val NOTIFICATION_ID = 73032
    private const val MAX_FOLDER_IMAGES = 500
    private const val MAX_NEW_IMAGES_PER_RUN = 50

    fun configureFolder(context: Context, treeUri: Uri) {
        val prefs = preferences(context)
        val folderUris = configuredFolderUris(context).toMutableSet()
        val uriText = treeUri.toString()
        folderUris.add(uriText)

        val knownDocumentIds = migratedKnownDocumentIds(prefs)
        collectImages(context, treeUri)
            .mapTo(knownDocumentIds) { documentKey(uriText, it.documentId) }

        prefs.edit()
            .putStringSet(FOLDER_URIS_KEY, folderUris)
            .remove(FOLDER_URI_KEY)
            .putStringSet(KNOWN_DOCUMENT_IDS_KEY, knownDocumentIds)
            .apply()
        schedule(context)
    }

    fun pendingImages(context: Context): List<String> {
        val paths = preferences(context)
            .getStringSet(PENDING_IMAGE_PATHS_KEY, emptySet())
            .orEmpty()
            .filter { File(it).isFile }
        if (paths.size != preferences(context)
                .getStringSet(PENDING_IMAGE_PATHS_KEY, emptySet())
                .orEmpty().size
        ) {
            preferences(context).edit()
                .putStringSet(PENDING_IMAGE_PATHS_KEY, paths.toSet())
                .apply()
        }
        return paths.sorted()
    }

    fun acknowledgeImages(context: Context, paths: Collection<String>) {
        if (paths.isEmpty()) return
        val remaining = preferences(context)
            .getStringSet(PENDING_IMAGE_PATHS_KEY, emptySet())
            .orEmpty()
            .toMutableSet()
        remaining.removeAll(paths.toSet())
        preferences(context).edit()
            .putStringSet(PENDING_IMAGE_PATHS_KEY, remaining)
            .apply()
    }

    @Synchronized
    fun scanAndQueue(context: Context, showNotification: Boolean): List<String> {
        val prefs = preferences(context)
        val folderUris = configuredFolderUris(context)
        if (folderUris.isEmpty()) return pendingImages(context)
        val knownIds = migratedKnownDocumentIds(prefs)
        val pendingPaths = prefs
            .getStringSet(PENDING_IMAGE_PATHS_KEY, emptySet())
            .orEmpty()
            .filterTo(mutableSetOf()) { File(it).isFile }

        val newImages = mutableListOf<ConfiguredFolderImage>()
        for (uriText in folderUris) {
            if (newImages.size >= MAX_NEW_IMAGES_PER_RUN) break
            val treeUri = Uri.parse(uriText)
            val images = try {
                collectImages(context, treeUri)
            } catch (_: Exception) {
                // A provider can temporarily be unavailable; keep scanning other albums.
                continue
            }
            images.asSequence()
                .filterNot { knownIds.contains(documentKey(uriText, it.documentId)) }
                .take(MAX_NEW_IMAGES_PER_RUN - newImages.size)
                .mapTo(newImages) { ConfiguredFolderImage(uriText, it) }
        }
        var copiedCount = 0
        for (configuredImage in newImages) {
            val image = configuredImage.image
            val copiedPath = copyToCache(context, image) ?: continue
            knownIds.add(documentKey(configuredImage.folderUri, image.documentId))
            pendingPaths.add(copiedPath)
            copiedCount++
        }

        prefs.edit()
            .putStringSet(KNOWN_DOCUMENT_IDS_KEY, knownIds)
            .putStringSet(PENDING_IMAGE_PATHS_KEY, pendingPaths)
            .apply()

        if (showNotification && copiedCount > 0) {
            showNewSlipNotification(context, copiedCount)
        }
        return pendingPaths.sorted()
    }

    private fun configuredFolderUris(context: Context): Set<String> {
        val prefs = preferences(context)
        val result = prefs
            .getStringSet(FOLDER_URIS_KEY, emptySet())
            .orEmpty()
            .toMutableSet()
        prefs.getString(FOLDER_URI_KEY, null)?.let(result::add)
        return result
    }

    private fun migratedKnownDocumentIds(
        prefs: android.content.SharedPreferences
    ): MutableSet<String> {
        val knownIds = prefs
            .getStringSet(KNOWN_DOCUMENT_IDS_KEY, emptySet())
            .orEmpty()
            .toMutableSet()
        val legacyUri = prefs.getString(FOLDER_URI_KEY, null) ?: return knownIds
        return knownIds.mapTo(mutableSetOf()) { id ->
            if (id.startsWith("$legacyUri|")) id else documentKey(legacyUri, id)
        }
    }

    private fun documentKey(folderUri: String, documentId: String): String {
        return "$folderUri|$documentId"
    }

    private fun schedule(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiresStorageNotLow(true)
            .build()
        val request = PeriodicWorkRequestBuilder<AutoSlipSyncWorker>(
            15,
            TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }

    private fun collectImages(context: Context, treeUri: Uri): List<FolderImage> {
        val images = mutableListOf<FolderImage>()
        val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
        collectImagesFromDocument(context, treeUri, rootDocumentId, images)
        return images
    }

    private fun collectImagesFromDocument(
        context: Context,
        treeUri: Uri,
        documentId: String,
        images: MutableList<FolderImage>
    ) {
        if (images.size >= MAX_FOLDER_IMAGES) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            documentId
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        context.contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
            )
            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )
            while (cursor.moveToNext() && images.size < MAX_FOLDER_IMAGES) {
                val childId = cursor.getString(idIndex)
                val name = cursor.getString(nameIndex) ?: "image"
                val mimeType = cursor.getString(mimeIndex) ?: ""
                if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                    collectImagesFromDocument(context, treeUri, childId, images)
                } else if (mimeType.startsWith("image/")) {
                    images.add(
                        FolderImage(
                            documentId = childId,
                            displayName = name,
                            uri = DocumentsContract.buildDocumentUriUsingTree(treeUri, childId)
                        )
                    )
                }
            }
        }
    }

    private fun copyToCache(context: Context, image: FolderImage): String? {
        val outputDir = File(context.cacheDir, "kimjod_auto_slip_sync").apply { mkdirs() }
        val safeName = image.displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val outputFile = File(
            outputDir,
            "${System.currentTimeMillis()}_${image.documentId.hashCode()}_$safeName"
        )
        return try {
            val input = context.contentResolver.openInputStream(image.uri) ?: return null
            input.use { source ->
                outputFile.outputStream().use { target -> source.copyTo(target) }
            }
            outputFile.absolutePath
        } catch (_: Exception) {
            outputFile.delete()
            null
        }
    }

    private fun showNewSlipNotification(context: Context, count: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Auto slip sync",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifies when new slip images are found in the selected folder."
                }
            )
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(OPEN_REQUEST_EXTRA, true)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(com.kimjot.project.R.drawable.ic_bg_service_small)
            .setContentTitle("พบสลิปใหม่ · New slips found")
            .setContentText("พบ $count รูปใหม่ แตะเพื่อตรวจและกดบันทึกเอง")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Notification permission can be denied; the pending queue remains in the app.
        }
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private data class FolderImage(
        val documentId: String,
        val displayName: String,
        val uri: Uri
    )

    private data class ConfiguredFolderImage(
        val folderUri: String,
        val image: FolderImage
    )
}

class AutoSlipSyncWorker(
    appContext: Context,
    workerParameters: WorkerParameters
) : Worker(appContext, workerParameters) {
    override fun doWork(): Result {
        return try {
            AutoSlipSync.scanAndQueue(applicationContext, showNotification = true)
            Result.success()
        } catch (_: Exception) {
            Result.success()
        }
    }
}
