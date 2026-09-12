package com.candor.candor

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
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
                    "modelSizes" -> {
                        val dir = File(filesDir, "models")
                        val sizes = mutableMapOf<String, Long>()
                        if (dir.exists()) {
                            dir.listFiles()?.forEach { sizes[it.name] = it.length() }
                        }
                        result.success(sizes)
                    }
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

        val speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "candor/speech")
        speechChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(SpeechRecognizer.isRecognitionAvailable(this))
                "start" -> {
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        pendingStart = true
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), SPEECH_REQ)
                        result.success(true) // grant may lag; recognizer starts on grant
                    } else if (startRecognizer(speechChannel)) {
                        result.success(true)
                    } else {
                        result.error("SPEECH_UNAVAILABLE", null, null)
                    }
                }
                "stop" -> {
                    recognizer?.stopListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val channel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, "candor/speech")
        if (requestCode == SPEECH_REQ && pendingStart) {
            pendingStart = false
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startRecognizer(channel)
            } else {
                channel.invokeMethod("onError", "permission")
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

    // ---- voice input (live captioning, offline-first) ----------------

    private var recognizer: SpeechRecognizer? = null
    private var pendingStart = false

    private fun startRecognizer(channel: MethodChannel): Boolean {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return false
        recognizer?.destroy()
        val rec = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = rec
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // Prefer the offline engine: voice input must never require a network.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        rec.setRecognitionListener(object : RecognitionListener {
            private fun send(method: String, arg: String?) =
                channel.invokeMethod(method, arg)

            override fun onPartialResults(results: Bundle?) {
                val s = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (s != null) send("onPartial", s)
            }

            override fun onResults(results: Bundle?) {
                val s = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (s != null) send("onFinal", s)
                send("onResultEnded", null)
                recognizer?.destroy()
                recognizer = null
            }

            override fun onError(error: Int) {
                val code = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                    SpeechRecognizer.ERROR_NETWORK,
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "recognition"
                    SpeechRecognizer.ERROR_NO_MATCH -> "nomatch"
                    else -> "recognition"
                }
                send("onError", code)
                recognizer?.destroy()
                recognizer = null
            }

            override fun onReadyForSpeech(p0: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(p0: Float) {}
            override fun onBufferReceived(p0: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(p0: Int, p1: Bundle?) {}
        })
        rec.startListening(intent)
        return true
    }

    companion object {
        private const val SPEECH_REQ = 3141
    }
}