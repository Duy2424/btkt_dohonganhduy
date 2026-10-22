// Danh sách app luôn được phép trong giờ khoá: chính ConAn, launcher, gọi điện mặc định, tin nhắn mặc định,
// đồng hồ/báo thức, cuộc gọi khẩn cấp, cộng thêm app phụ huynh chọn trong lịch.
package com.dohonganhduy.btkt_dohonganhduy.nativebridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import android.provider.Telephony
import android.telecom.TelecomManager

object AllowedApps {
    private var cached: Set<String>? = null

    fun always(context: Context): Set<String> {
        cached?.let { return it }
        val pm = context.packageManager
        val set = mutableSetOf(
            context.packageName,
            "com.android.systemui",
            "com.android.phone",
            "com.android.server.telecom",
            "com.android.emergency",
        )
        val intents = listOf(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            Intent(AlarmClock.ACTION_SHOW_ALARMS),
            Intent(Intent.ACTION_DIAL),
            Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:")),
        )
        for (intent in intents) {
            pm.queryIntentActivities(intent, 0).forEach { set.add(it.activityInfo.packageName) }
        }
        (context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)?.defaultDialerPackage?.let { set.add(it) }
        Telephony.Sms.getDefaultSmsPackage(context)?.let { set.add(it) }
        cached = set
        return set
    }

    fun isAllowed(context: Context, window: LockWindow, pkg: String) = pkg in always(context) || pkg in window.allowed
}
