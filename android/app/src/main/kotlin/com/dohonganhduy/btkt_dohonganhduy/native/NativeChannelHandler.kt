// Xử lý MethodChannel "conan/native" (wrapper Dart: lib/core/platform/native_channel.dart):
// kiểm tra / mở quyền "Truy cập dữ liệu sử dụng" và "Hiển thị trên ứng dụng khác", danh sách app có icon,
// mở trang cài đặt riêng của Xiaomi, bật/tắt dịch vụ khoá máy. (Package "nativebridge" vì "native" là từ khoá của Java.)
package com.dohonganhduy.btkt_dohonganhduy.nativebridge

import android.app.Activity
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NativeChannelHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" -> result.success(open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)))
            "canDrawOverlays" -> result.success(Settings.canDrawOverlays(activity))
            "openOverlaySettings" -> result.success(
                open(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}")))
            )
            "openAppDetailsSettings" -> result.success(
                open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")))
            )
            "openXiaomiSettings" -> result.success(openXiaomi(call.arguments as? String ?: ""))
            "getLaunchableApps" -> result.success(launchableApps())
            // Dịch vụ khoá máy theo lịch: lưu cấu hình (chạy được khi mất mạng) rồi bật LockService
            "startLockService" -> {
                LockConfig.save(activity, call.arguments as? String)
                LockService.start(activity)
                result.success(true)
            }
            "updateLockConfig" -> {
                LockConfig.save(activity, call.arguments as? String)
                result.success(true)
            }
            "stopLockService" -> {
                LockConfig.save(activity, null)
                LockService.stop(activity)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun open(intent: Intent): Boolean = try {
        activity.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), activity.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), activity.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Chỉ app có icon ngoài launcher (khai báo <queries> MAIN/LAUNCHER trong manifest). */
    private fun launchableApps(): List<Map<String, String>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { mapOf("packageName" to it.activityInfo.packageName, "label" to it.loadLabel(pm).toString()) }
            .filter { it["packageName"] != activity.packageName }
            .distinctBy { it["packageName"] }
    }

    /** Trang cài đặt riêng của MIUI/HyperOS; không mở được → trả false để Dart mở trang chi tiết app + hướng dẫn. */
    private fun openXiaomi(page: String): Boolean {
        val intent = when (page) {
            "autostart" -> Intent().setComponent(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
            )
            "popup" -> Intent("miui.intent.action.APP_PERM_EDITOR")
                .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                .putExtra("extra_pkgname", activity.packageName)
            "battery" -> Intent().setComponent(
                ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
            ).putExtra("package_name", activity.packageName).putExtra("package_label", "ConAn")
            else -> return false
        }
        return open(intent)
    }
}
