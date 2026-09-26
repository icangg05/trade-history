package com.tradehistory.trade_history

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

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
}
