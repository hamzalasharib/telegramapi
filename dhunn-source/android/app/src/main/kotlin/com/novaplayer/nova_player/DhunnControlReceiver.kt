package com.novaplayer.nova_player

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import androidx.core.content.ContextCompat

/// Widget transport controls (v2.34 rework).
///
/// v2.31–v2.33 pointed the widget buttons straight at
/// audio_service's MediaButtonReceiver. On this phone (OPPO
/// ColorOS) a tap while the playback service was not already
/// running ended in "Dhunn has stopped": the androidx receiver
/// starts the foreground service from a background broadcast,
/// which ColorOS/Android 12+ can reject with an exception
/// inside OUR process — and an uncaught exception in a
/// broadcast receiver IS an app crash.
///
/// This receiver is the crash-proof middleman:
///  • Playback service already running → forward the same
///    media-button intent directly to the AudioService
///    component (identical delivery to before, in-process,
///    everything wrapped so a failure can never crash us).
///  • Service not running → a media button would boot an
///    EMPTY background handler (no queue after the process
///    died), so instead launch the app with the action as an
///    extra; Dart restores the saved session (v2.9) and
///    performs it — the song actually plays, which is what
///    the user asked for ("app close ho to bhi widget se
///    play ho jaye").
class DhunnControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val action = intent.action ?: return
            val keyCode = when (action) {
                DhunnWidgetProvider.ACTION_PLAY_PAUSE ->
                    KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                DhunnWidgetProvider.ACTION_NEXT ->
                    KeyEvent.KEYCODE_MEDIA_NEXT
                DhunnWidgetProvider.ACTION_PREV ->
                    KeyEvent.KEYCODE_MEDIA_PREVIOUS
                else -> return
            }
            if (isPlaybackRunning(context)) {
                val svc = Intent(Intent.ACTION_MEDIA_BUTTON)
                    .setComponent(ComponentName(context.packageName,
                        "com.ryanheise.audioservice.AudioService"))
                    .putExtra(Intent.EXTRA_KEY_EVENT,
                        KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
                try {
                    ContextCompat.startForegroundService(context, svc)
                    return
                } catch (t: Throwable) {
                    // fall through to the app-launch route
                }
            }
            launchApp(context, action)
        } catch (t: Throwable) {
            // A widget tap must NEVER crash the app.
            try { launchApp(context, intent.action ?: "") } catch (_: Throwable) { }
        }
    }

    private fun isPlaybackRunning(context: Context): Boolean {
        return try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE)
                as? ActivityManager ?: return false
            @Suppress("DEPRECATION")
            val services = am.getRunningServices(64) ?: return false
            services.any {
                it.service.className == "com.ryanheise.audioservice.AudioService"
            }
        } catch (t: Throwable) {
            false
        }
    }

    private fun launchApp(context: Context, action: String) {
        val name = when (action) {
            DhunnWidgetProvider.ACTION_NEXT -> "next"
            DhunnWidgetProvider.ACTION_PREV -> "prev"
            else -> "play_pause"
        }
        val launch = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(DhunnWidgetProvider.EXTRA_WIDGET_ACTION, name)
        context.startActivity(launch)
    }
}
