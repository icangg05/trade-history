package com.tradehistory.trade_history

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Flutter tidak pernah meminta refresh rate, dan banyak HP (Xiaomi,
        // Infinix, OnePlus, ...) menjalankan aplikasi seperti itu di 60 Hz walau
        // layarnya 90/120 Hz. Minta yang tertinggi di resolusi sekarang: pilihan
        // refresh rate di pengaturan HP dan mode hemat baterai tetap lebih kuat,
        // jadi hasilnya selalu mengikuti pengaturan sistem.
        @Suppress("DEPRECATION")
        val screen = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay) ?: return
        val size = screen.mode
        val fastest = screen.supportedModes
            .filter { it.physicalWidth == size.physicalWidth && it.physicalHeight == size.physicalHeight }
            .maxOfOrNull { it.refreshRate } ?: return

        window.attributes = window.attributes.apply { preferredRefreshRate = fastest }
    }

    // Simpan berkas ke folder Download publik lewat MediaStore — tanpa izin
    // penyimpanan. Android 9 ke bawah tidak punya MediaStore.Downloads, jadi
    // `notImplemented` dan Dart jatuh ke lembar bagikan.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Nama HP untuk daftar perangkat: yang tertulis di Setelan › Tentang
        // ponsel ("Redmi Note 12 Pro"), atau merek + model kalau kosong.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trade_history/device")
            .setMethodCallHandler { _, result ->
                val named = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                    Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME)
                } else null
                val model = if (Build.MODEL.startsWith(Build.MANUFACTURER, ignoreCase = true)) {
                    Build.MODEL
                } else {
                    "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}"
                }

                result.success(named?.takeIf { it.isNotBlank() } ?: model)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trade_history/downloads")
            .setMethodCallHandler { call, result ->
                if (call.method != "save" || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    return@setMethodCallHandler result.notImplemented()
                }

                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, call.argument<String>("name"))
                    put(MediaStore.MediaColumns.MIME_TYPE, call.argument<String>("mime"))
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }

                try {
                    val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)!!
                    contentResolver.openOutputStream(uri)!!.use { it.write(call.argument<ByteArray>("bytes")!!) }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
    }
}
