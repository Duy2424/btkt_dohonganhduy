// Lịch khoá máy lưu sẵn trên máy con (SharedPreferences) nên mất mạng vẫn khoá được.
// active(): khung khoá đang hiệu lực, cùng quy tắc với server (utils/time.js), hỗ trợ qua nửa đêm (vd 21:30–06:30).
package com.dohonganhduy.btkt_dohonganhduy.nativebridge

import android.content.Context
import org.json.JSONObject
import java.util.Calendar

data class LockWindow(
    val name: String,
    val days: Set<Int>, // 1 = Thứ 2 … 7 = Chủ nhật
    val start: Int, // phút từ 00:00
    val end: Int,
    val allowed: Set<String>,
)

object LockConfig {
    private const val PREFS = "conan_lock"
    private const val KEY = "config"

    fun save(context: Context, json: String?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
    }

    fun load(context: Context): List<LockWindow> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONObject(raw).optJSONArray("lockSchedules") ?: return emptyList()
            (0 until arr.length())
                .map { arr.getJSONObject(it) }
                .filter { it.optBoolean("enabled", true) }
                .map { o ->
                    val days = o.getJSONArray("daysOfWeek")
                    val allowed = o.optJSONArray("allowedPackages")
                    LockWindow(
                        name = o.optString("name"),
                        days = (0 until days.length()).map { days.getInt(it) }.toSet(),
                        start = minutes(o.getString("startTime")),
                        end = minutes(o.getString("endTime")),
                        allowed = if (allowed == null) emptySet() else (0 until allowed.length()).map { allowed.getString(it) }.toSet(),
                    )
                }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun minutes(hhmm: String): Int {
        val p = hhmm.split(":")
        return p[0].toInt() * 60 + p[1].toInt()
    }

    fun active(windows: List<LockWindow>, now: Calendar = Calendar.getInstance()): LockWindow? {
        val cur = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val dow = now.get(Calendar.DAY_OF_WEEK) // Calendar: 1 = Chủ nhật … 7 = Thứ 7
        val today = if (dow == Calendar.SUNDAY) 7 else dow - 1
        val yesterday = if (today == 1) 7 else today - 1
        return windows.firstOrNull { w ->
            when {
                w.start < w.end -> today in w.days && cur >= w.start && cur < w.end
                cur >= w.start -> today in w.days
                else -> cur < w.end && yesterday in w.days // phần sau nửa đêm thuộc ngày hôm trước
            }
        }
    }

    fun endText(w: LockWindow) = "%02d:%02d".format(w.end / 60, w.end % 60)
}
