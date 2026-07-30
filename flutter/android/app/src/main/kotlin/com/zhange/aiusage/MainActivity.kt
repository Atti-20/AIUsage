package com.zhange.aiusage

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aiusage/widget",
        ).setMethodCallHandler { call, result ->
            if (call.method == "reload") {
                UsageWidgetProvider.updateAll(this)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
