// Foreground service thực thi lịch khoá máy (mức đồ án, không cần Device Owner):
// mỗi ~1 giây đọc app đang mở bằng UsageStatsManager; trong khung giờ khoá mà app không được phép → mở LockActivity.
// Giới hạn: trẻ vẫn có thể gỡ app / tắt quyền trong Cài đặt (server sẽ cảnh báo phụ huynh khi quyền bị tắt).
package com.dohonganhduy.btkt_dohonganhduy.nativebridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class LockService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var lastForeground: String? = null
    private var lastLockShownAt = 0L

    private val tick = object : Runnable {
        override fun run() {
            try {
                checkForegroundApp()
            } catch (_: Exception) {
            }
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    private fun startAsForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Lịch khoá máy", NotificationManager.IMPORTANCE_LOW))
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("ConAn đang áp dụng lịch khoá máy")
            .setContentText("Bố mẹ đặt giờ nghỉ dùng điện thoại cho con")
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun checkForegroundApp() {
        val window = LockConfig.active(LockConfig.load(this)) ?: return
        val pkg = currentForegroundPackage() ?: return
        if (AllowedApps.isAllowed(this, window, pkg)) return
        val now = System.currentTimeMillis()
        if (now - lastLockShownAt < 1500) return
        lastLockShownAt = now
        startActivity(
            Intent(this, LockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(LockActivity.EXTRA_UNTIL, LockConfig.endText(window))
                .putExtra(LockActivity.EXTRA_NAME, window.name),
        )
    }

    /** App vừa lên màn hình gần nhất (sự kiện ACTIVITY_RESUMED = 1). */
    private fun currentForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = if (lastForeground == null) end - 60 * 60 * 1000 else end - 10_000
        val events = usm.queryEvents(start, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == 1) lastForeground = event.packageName
        }
        return lastForeground
    }

    companion object {
        private const val CHANNEL_ID = "conan_lock"
        private const val NOTIFICATION_ID = 889

        fun start(context: Context) {
            val intent = Intent(context, LockService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LockService::class.java))
        }
    }
}
