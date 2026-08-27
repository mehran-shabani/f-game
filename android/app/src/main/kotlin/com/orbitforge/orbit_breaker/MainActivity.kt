package com.orbitforge.orbit_breaker

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 72)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.orbitforge.orbit_breaker/feedback",
        ).setMethodCallHandler { call, result ->
            if (call.method != "playFeedback") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val cue = call.argument<String>("cue") ?: "turn"
            if (call.argument<Boolean>("sound") == true) playTone(cue)
            if (call.argument<Boolean>("haptics") == true) vibrate(cue)
            result.success(null)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        toneGenerator?.release()
        toneGenerator = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun playTone(cue: String) {
        val (tone, duration) = when (cue) {
            "start" -> ToneGenerator.TONE_PROP_ACK to 90
            "crystal" -> ToneGenerator.TONE_PROP_BEEP2 to 70
            "nearMiss" -> ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD to 65
            "shield" -> ToneGenerator.TONE_CDMA_HIGH_L to 150
            "gameOver" -> ToneGenerator.TONE_SUP_ERROR to 260
            else -> ToneGenerator.TONE_PROP_BEEP to 35
        }
        toneGenerator?.startTone(tone, duration)
    }

    @Suppress("DEPRECATION")
    private fun vibrator(): Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    @Suppress("DEPRECATION")
    private fun vibrate(cue: String) {
        val deviceVibrator = vibrator()
        if (!deviceVibrator.hasVibrator()) return

        val timings = when (cue) {
            "crystal" -> longArrayOf(0, 28, 32, 38)
            "nearMiss" -> longArrayOf(0, 42)
            "shield" -> longArrayOf(0, 70, 35, 110)
            "gameOver" -> longArrayOf(0, 90, 45, 150)
            "start" -> longArrayOf(0, 35, 28, 45)
            else -> longArrayOf(0, 18)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            deviceVibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
        } else {
            deviceVibrator.vibrate(timings, -1)
        }
    }
}
