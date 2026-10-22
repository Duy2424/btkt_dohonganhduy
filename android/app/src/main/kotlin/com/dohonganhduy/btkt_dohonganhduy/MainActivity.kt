// Activity chính của app ConAn, đăng ký MethodChannel "conan/native" (code native nằm trong thư mục native/).
package com.dohonganhduy.btkt_dohonganhduy

import com.dohonganhduy.btkt_dohonganhduy.nativebridge.NativeChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "conan/native")
            .setMethodCallHandler(NativeChannelHandler(this))
    }
}
