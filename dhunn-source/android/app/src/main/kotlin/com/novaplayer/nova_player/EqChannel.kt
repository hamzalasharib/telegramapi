package com.novaplayer.nova_player

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Native audio-FX for the player: attaches Equalizer / BassBoost /
/// LoudnessEnhancer to the audio session reported by just_audio.
/// Effects are independent of the player pipeline, which is why this
/// works on OEM ROMs where in-pipeline Dart effects never engaged.
object EqChannel {
    private var eq: Equalizer? = null
    private var bass: BassBoost? = null
    private var loud: LoudnessEnhancer? = null
    private var virt: Virtualizer? = null
    private var sessionId: Int = -1

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                val sid = call.argument<Int>("sessionId") ?: -1
                if (sid <= 0) { result.success(null); return }
                try {
                    releaseAll()
                    sessionId = sid
                    val e = Equalizer(0, sid)
                    eq = e
                    bass = try { BassBoost(0, sid) } catch (t: Throwable) { null }
                    loud = try { LoudnessEnhancer(sid) } catch (t: Throwable) { null }
                    virt = try { Virtualizer(0, sid) } catch (t: Throwable) { null }
                    val n = e.numberOfBands.toInt()
                    val range = e.bandLevelRange
                    val freqs = (0 until n).map { e.getCenterFreq(it.toShort()) / 1000 }
                    result.success(mapOf(
                        "bands" to n,
                        "min" to range[0].toInt(),
                        "max" to range[1].toInt(),
                        "freqs" to freqs,
                        "virt" to (virt != null),
                    ))
                } catch (t: Throwable) {
                    releaseAll()
                    result.success(null)
                }
            }
            "setEnabled" -> {
                val on = call.argument<Boolean>("enabled") ?: true
                try { eq?.enabled = on } catch (t: Throwable) {}
                try { bass?.enabled = on } catch (t: Throwable) {}
                try { loud?.enabled = on } catch (t: Throwable) {}
                try { virt?.enabled = on } catch (t: Throwable) {}
                result.success(null)
            }
            "setBand" -> {
                val band = call.argument<Int>("band") ?: 0
                val level = call.argument<Int>("level") ?: 0
                try { eq?.setBandLevel(band.toShort(), level.toShort()) } catch (t: Throwable) {}
                result.success(null)
            }
            "setBass" -> {
                val s = call.argument<Int>("strength") ?: 0
                try {
                    bass?.enabled = s > 0
                    bass?.setStrength(s.toShort())
                } catch (t: Throwable) {}
                result.success(null)
            }
            "setLoud" -> {
                val g = call.argument<Int>("gain") ?: 0
                try {
                    loud?.enabled = g > 0
                    loud?.setTargetGain(g)
                } catch (t: Throwable) {}
                result.success(null)
            }
            "setVirt" -> {
                val s = call.argument<Int>("strength") ?: 0
                try {
                    virt?.enabled = s > 0
                    virt?.setStrength(s.toShort())
                } catch (t: Throwable) {}
                result.success(null)
            }
            "release" -> { releaseAll(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun releaseAll() {
        try { eq?.release() } catch (t: Throwable) {}
        try { bass?.release() } catch (t: Throwable) {}
        try { loud?.release() } catch (t: Throwable) {}
        try { virt?.release() } catch (t: Throwable) {}
        eq = null; bass = null; loud = null; virt = null; sessionId = -1
    }
}
