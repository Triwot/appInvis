package com.example.invita_pro

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

/**
 * Puente nativo para publicar archivos generados en la galería del dispositivo
 * dentro de una carpeta propia (ej. Movies/InvitaPro/MiEvento).
 *
 * - Android 10+ (API 29+): MediaStore con RELATIVE_PATH (sin permisos de almacenamiento).
 * - Android 9 o menor: copia directa a carpeta pública + MediaScanner
 *   (requiere WRITE_EXTERNAL_STORAGE, declarado con maxSdkVersion=28).
 */
class MainActivity : FlutterActivity() {

    private val channelName = "invitapro/media_store"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> onCall(call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "invitapro/foreground")
            .setMethodCallHandler { call, result -> onForegroundCall(call, result) }
    }

    /**
     * Control del servicio en primer plano:
     *  - start(title, text): arranca el servicio + notificación persistente.
     *  - update(title, text, percent): actualiza la notificación (percent 0..100).
     *  - finish(title, text): detiene el servicio y avisa con una notificación final.
     *  - stop(): detiene el servicio sin aviso (cancelación).
     */
    private fun onForegroundCall(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "InvitaPro"
        val text = call.argument<String>("text") ?: ""
        try {
            when (call.method) {
                "start" -> {
                    BatchForegroundService.ensureChannels(this)
                    val intent = Intent(this, BatchForegroundService::class.java)
                        .putExtra(BatchForegroundService.EXTRA_TITLE, title)
                        .putExtra(BatchForegroundService.EXTRA_TEXT, text)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "update" -> {
                    val percent = call.argument<Int>("percent")
                    BatchForegroundService.notify(
                        this,
                        BatchForegroundService.NOTIFICATION_ID,
                        BatchForegroundService.progressNotification(this, title, text, percent)
                    )
                    result.success(true)
                }
                "finish" -> {
                    stopService(Intent(this, BatchForegroundService::class.java))
                    BatchForegroundService.notify(
                        this,
                        BatchForegroundService.DONE_NOTIFICATION_ID,
                        BatchForegroundService.doneNotification(this, title, text)
                    )
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, BatchForegroundService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("FGS_ERROR", e.message, null)
        }
    }


    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveToGallery" -> {
                val path = call.argument<String>("path")
                val mime = call.argument<String>("mimeType")
                val dir = call.argument<String>("relativeDir") // ej. "Movies/InvitaPro/Boda"
                val name = call.argument<String>("displayName")
                if (path == null || mime == null || dir == null || name == null) {
                    result.error("ARGS", "Argumentos incompletos", null)
                    return
                }
                Thread {
                    try {
                        val saved = saveToGallery(File(path), mime, dir, name)
                        mainHandler.post { result.success(saved) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("SAVE_FAILED", e.message, null) }
                    }
                }.start()
            }
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            else -> result.notImplemented()
        }
    }

    private fun saveToGallery(src: File, mime: String, relativeDir: String, name: String): String {
        val isVideo = mime.startsWith("video/")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (isVideo)
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativeDir)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("No se pudo crear el registro en MediaStore")
            try {
                resolver.openOutputStream(uri)!!.use { out ->
                    FileInputStream(src).use { it.copyTo(out, 1024 * 256) }
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return "$relativeDir/$name"
        } else {
            @Suppress("DEPRECATION")
            val root = Environment.getExternalStorageDirectory()
            val target = File(File(root, relativeDir), name)
            target.parentFile?.mkdirs()
            src.copyTo(target, overwrite = true)
            MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(mime), null)
            return target.absolutePath
        }
    }
}
