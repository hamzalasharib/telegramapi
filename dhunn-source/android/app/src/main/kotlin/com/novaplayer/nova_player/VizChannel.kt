package com.novaplayer.nova_player

import android.media.audiofx.Visualizer
import io.flutter.plugin.common.EventChannel
import kotlin.math.sqrt

/**
 * Beat feed for the Fluid Beat background (v2.12): streams the BASS
 * energy (0..1) of whatever is playing on the given audio session,
 * computed from the system Visualizer's FFT. ~20 events/second.
 *
 * Needs RECORD_AUDIO at runtime; without it the Visualizer throws
 * and we report an error so Dart can fall back to a synthetic pulse.
 */
class VizChannel : EventChannel.StreamHandler {

    private var viz: Visualizer? = null
    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sessionId = (arguments as? Number)?.toInt() ?: 0
        if (sessionId == 0) {
            events?.error("no_session", "Audio session not ready", null)
            return
        }
        try {
            val v = Visualizer(sessionId)
            val size = Visualizer.getCaptureSizeRange()[1]
            v.captureSize = size
            v.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?, waveform: ByteArray?, samplingRate: Int
                    ) {
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer?, fft: ByteArray?, samplingRate: Int
                    ) {
                        if (fft == null) return
                        // FFT bytes: [dc, nyquist, re, im, re, im, ...]
                        // Bass lives in the first few bins.
                        var sum = 0.0
                        var n = 0
                        var i = 2
                        while (i + 1 < fft.size && n < 6) {
                            val re = fft[i].toDouble()
                            val im = fft[i + 1].toDouble()
                            sum += sqrt(re * re + im * im)
                            n++
                            i += 2
                        }
                        if (n == 0) return
                        val avg = sum / n // ~0..180 for typical music
                        sink?.success((avg / 105.0).coerceIn(0.0, 1.0))
                    }
                },
                Visualizer.getMaxCaptureRate() / 2,
                false,
                true
            )
            v.enabled = true
            viz = v
        } catch (e: Exception) {
            events?.error("viz_failed", e.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        try {
            viz?.enabled = false
            viz?.release()
        } catch (e: Exception) {
        }
        viz = null
    }
}
