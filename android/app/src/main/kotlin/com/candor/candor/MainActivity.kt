package com.candor.candor

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candor/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryPercent" -> result.success(batteryPercent())
                    "getThermalStatus" -> result.success(thermalStatus())
                    "listModels" -> result.success(listModels())
                    "prepareModel" -> {
                        val name = call.argument<String>("name")
                        if (name == null) {
                            result.error("BAD_ARGS", "name is required", null)
                        } else {
                            result.success(prepareModel(name))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun batteryPercent(): Int {
        if (Build.VERSION.SDK_INT >= 21) {
            val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        }
        return 100
    }

    private fun thermalStatus(): Int {
        if (Build.VERSION.SDK_INT >= 29) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.currentThermalStatus
        }
        return PowerManager.THERMAL_STATUS_NONE
    }

    // Bundled GGUF names for the model picker.
    private fun listModels(): List<String> {
        return assets.list("models")?.toList() ?: emptyList()
    }

    // Assets can't be loaded as a file path by llama.cpp, so stream-copy the bundled
    // GGUF into app-private storage on first launch (avoids loading ~1GB into Dart memory).
    private fun prepareModel(name: String): String {
        val out = File(filesDir, "models/$name")
        if (out.exists()) return out.absolutePath
        assets.open("models/$name").use { input ->
            out.parentFile?.mkdirs()
            out.outputStream().use { output -> input.copyTo(output) }
        }
        return out.absolutePath
    }
}