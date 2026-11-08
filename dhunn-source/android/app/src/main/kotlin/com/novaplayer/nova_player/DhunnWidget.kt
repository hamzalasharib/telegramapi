package com.novaplayer.nova_player

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews

/// Home-screen player widget (v2.31; controls + colours reworked
/// in v2.34): cover on top, prev / play-pause / next below it, and
/// the LIVE lyric line under the controls.
///
/// The widget itself is dumb on purpose: the Dart WidgetSync
/// service resolves the current song + lyrics (same offline
/// order as the player: custom -> sidecar -> cache -> LRCLIB)
/// and pushes {title, artist, line, next, art, playing, color,
/// fx} over the "nova/widget" channel. Values land in a small
/// prefs file; every push re-renders all placed widgets
/// instantly.
///
/// v2.34 changes (his reports):
///  • Controls go through DhunnControlReceiver instead of
///    audio_service's MediaButtonReceiver — a tap can no
///    longer crash the app, and Play works even when the app
///    was closed (the app opens, restores the session, plays).
///  • The cover is decoded DOWNSAMPLED (max 288px). The old
///    code decoded the full-size HD cover into the RemoteViews
///    on every push (every lyric line!): a multi-megapixel
///    bitmap in a Binder transaction is a crash/jank hazard.
///  • Colours follow the music: the widget background wears a
///    dark shade of the cover's dominant colour and the live
///    lyric line wears the current lyrics-effect colour, both
///    pushed by Dart on every song change.
class DhunnWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateOne(context, appWidgetManager, id)
    }

    companion object {
        private const val PREFS = "dhunn_widget"

        const val ACTION_PLAY_PAUSE = "com.novaplayer.nova_player.widget.PLAY_PAUSE"
        const val ACTION_NEXT = "com.novaplayer.nova_player.widget.NEXT"
        const val ACTION_PREV = "com.novaplayer.nova_player.widget.PREV"
        const val EXTRA_WIDGET_ACTION = "dhunn_widget_action"

        /// Called from MainActivity's nova/widget channel.
        fun storeAndRefresh(context: Context, values: Map<*, *>) {
            val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            e.putString("title", values["title"] as? String ?: "")
            e.putString("artist", values["artist"] as? String ?: "")
            e.putString("line", values["line"] as? String ?: "")
            e.putString("next", values["next"] as? String ?: "")
            e.putString("art", values["art"] as? String ?: "")
            e.putBoolean("playing", values["playing"] as? Boolean ?: false)
            e.putInt("color", (values["color"] as? Number)?.toInt() ?: 0)
            e.putInt("fx", (values["fx"] as? Number)?.toInt() ?: 0)
            e.apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, DhunnWidgetProvider::class.java))
            for (id in ids) updateOne(context, mgr, id)
        }

        private fun control(context: Context, action: String, req: Int): PendingIntent {
            val intent = Intent(context, DhunnControlReceiver::class.java)
                .setAction(action)
            return PendingIntent.getBroadcast(
                context, req, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        /// Decode [path] downsampled so the longest side is at
        /// most ~288px — plenty for a widget, tiny in Binder.
        private fun decodeSmall(path: String): Bitmap? {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            while (longest / (sample * 2) >= 288) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            return BitmapFactory.decodeFile(path, opts)
        }

        private fun updateOne(context: Context, mgr: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.dhunn_widget)
            val title = prefs.getString("title", "") ?: ""
            views.setTextViewText(R.id.w_title, if (title.isEmpty()) "Dhunn" else title)
            val artist = prefs.getString("artist", "") ?: ""
            views.setTextViewText(R.id.w_artist,
                if (artist.isEmpty()) "Your music" else artist)
            views.setTextViewText(R.id.w_line, prefs.getString("line", "") ?: "")
            views.setTextViewText(R.id.w_next_line, prefs.getString("next", "") ?: "")
            val playing = prefs.getBoolean("playing", false)
            views.setImageViewResource(R.id.w_play,
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play)
            // Colours that follow the music (v2.34): background =
            // dark shade of the cover colour; the live lyric line
            // wears the lyrics-effect colour, the next line the
            // same colour dimmed. 0 = not set yet, keep defaults.
            val bg = prefs.getInt("color", 0)
            if (bg != 0) {
                try { views.setInt(R.id.w_root, "setBackgroundColor", bg) }
                catch (t: Throwable) { }
            }
            val fx = prefs.getInt("fx", 0)
            if (fx != 0) {
                views.setTextColor(R.id.w_line, fx)
                val dim = (fx and 0x00FFFFFF) or 0x8C000000.toInt()
                views.setTextColor(R.id.w_next_line, dim)
            }
            // Cover: the HD/local file path Dart sends, decoded
            // small; fall back to the app icon when there is none.
            val art = prefs.getString("art", "") ?: ""
            var set = false
            if (art.startsWith("/")) {
                try {
                    val bmp = decodeSmall(art)
                    if (bmp != null) {
                        views.setImageViewBitmap(R.id.w_art, bmp)
                        set = true
                    }
                } catch (t: Throwable) { }
            }
            if (!set) views.setImageViewResource(R.id.w_art, R.mipmap.ic_launcher)
            views.setOnClickPendingIntent(R.id.w_prev,
                control(context, ACTION_PREV, 2311))
            views.setOnClickPendingIntent(R.id.w_play,
                control(context, ACTION_PLAY_PAUSE, 2312))
            views.setOnClickPendingIntent(R.id.w_next,
                control(context, ACTION_NEXT, 2313))
            val launch = Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            views.setOnClickPendingIntent(R.id.w_art,
                PendingIntent.getActivity(context, 2314, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            mgr.updateAppWidget(id, views)
        }
    }
}
