// Màn hình "Đang trong giờ nghỉ, đến HH:mm" hiện lên khi con mở app không được phép trong giờ khoá.
// Có nút mở nhanh các app luôn được phép: gọi điện, tin nhắn, báo thức, màn hình chính.
package com.dohonganhduy.btkt_dohonganhduy.nativebridge

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.AlarmClock
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class LockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val until = intent.getStringExtra(EXTRA_UNTIL) ?: ""
        val name = intent.getStringExtra(EXTRA_NAME) ?: "Giờ nghỉ"

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(64, 64, 64, 64)
            setBackgroundColor(Color.parseColor("#0F766E"))
        }
        fun text(value: String, size: Float) = TextView(this).apply {
            text = value
            textSize = size
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 12, 0, 12)
        }
        fun button(label: String, target: Intent) = Button(this).apply {
            text = label
            textSize = 18f
            setOnClickListener { open(target) }
        }

        layout.addView(text("🌙", 64f))
        layout.addView(text("Đang trong giờ nghỉ", 30f))
        layout.addView(text("đến $until", 24f))
        layout.addView(text("Bố mẹ đã đặt lịch \"$name\".\nCon vẫn gọi điện, nhắn tin và đặt báo thức được.", 16f))
        layout.addView(button("📞  Gọi điện", Intent(Intent.ACTION_DIAL)))
        layout.addView(button("💬  Tin nhắn", Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:"))))
        layout.addView(button("⏰  Báo thức", Intent(AlarmClock.ACTION_SHOW_ALARMS)))
        layout.addView(button("🏠  Màn hình chính", homeIntent()))
        setContentView(layout)
    }

    private fun homeIntent() = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)

    private fun open(target: Intent) {
        try {
            startActivity(target.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
        }
        finish()
    }

    // Nút Back: về màn hình chính thay vì quay lại app bị khoá
    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        open(homeIntent())
    }

    companion object {
        const val EXTRA_UNTIL = "until"
        const val EXTRA_NAME = "name"
    }
}
