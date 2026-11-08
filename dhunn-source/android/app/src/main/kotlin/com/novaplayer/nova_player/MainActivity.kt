package com.novaplayer.nova_player

import android.content.Intent
import android.net.Uri
import android.content.ContentUris
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

/// IMPORTANT: this activity MUST extend AudioServiceActivity (not plain
/// FlutterActivity). Without it, AudioService.init() inside
/// JustAudioBackground.init() throws in main(), which leaves
/// just_audio_background's platform swapped in with its `_audioHandler`
/// late field never assigned — every single playback then dies with
/// "LateInitializationError: Field '_audioHandler...'". That was the
/// root cause of "songs list but never play" in v1.0 and v1.1.
class MainActivity : AudioServiceActivity() {
    private var bgPickResult: MethodChannel.Result? = null
    // Song opened from a file manager (v2.21): the VIEW intent's
    // data, kept until Dart asks for it over nova/openfile.
    private var pendingOpened: Uri? = null
    // Widget transport action (v2.34): DhunnControlReceiver
    // launches us with this extra when the playback service is
    // dead; Dart performs it after restoring the saved session.
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == Intent.ACTION_VIEW) pendingOpened = intent?.data
        pendingWidgetAction =
            intent?.getStringExtra(DhunnWidgetProvider.EXTRA_WIDGET_ACTION)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) pendingOpened = intent.data
        val action = intent.getStringExtra(DhunnWidgetProvider.EXTRA_WIDGET_ACTION)
        if (action != null) {
            pendingWidgetAction = action
            // Engine already alive: hand it over right away.
            try { widgetChannel?.invokeMethod("widgetAction", action) }
            catch (t: Throwable) { }
        }
    }

    private var textPickResult: MethodChannel.Result? = null
    private var folderPickResult: MethodChannel.Result? = null
    private var adsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/openfile")
            .setMethodCallHandler { call, result ->
                if (call.method == "takeOpened") {
                    val uri = pendingOpened
                    if (uri == null) {
                        result.success(null)
                    } else {
                        pendingOpened = null
                        thread {
                            val info = openedInfo(uri)
                            Handler(Looper.getMainLooper()).post { result.success(info) }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/files")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickFolder") {
                    // Folder picker (v2.20): ACTION_OPEN_DOCUMENT_TREE;
                    // the result is converted to a real path in
                    // onActivityResult (request 4715).
                    folderPickResult = result
                    val intent = android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT_TREE)
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, 4715)
                } else if (call.method == "shareFile") {
                    // Share a song file (v2.23) via FileProvider so
                    // other apps can read it.
                    val path = call.argument<String>("path") ?: ""
                    val title = call.argument<String>("title") ?: "song"
                    try {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this, packageName + ".fileprovider", java.io.File(path))
                        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = "audio/*"
                            putExtra(android.content.Intent.EXTRA_STREAM, uri)
                            putExtra(android.content.Intent.EXTRA_TITLE, title)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(android.content.Intent.createChooser(intent, "Share song"))
                        result.success(true)
                    } catch (e: Throwable) {
                        result.success(false)
                    }
                } else if (call.method == "pickText") {
                    textPickResult = result
                    val intent = android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(android.content.Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(android.content.Intent.EXTRA_MIME_TYPES, arrayOf("text/*", "application/octet-stream"))
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, 4714)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/bg")
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    bgPickResult = result
                    val intent = android.content.Intent(android.content.Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(android.content.Intent.CATEGORY_OPENABLE)
                        type = "image/*"
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, 4713)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/eq")
            .setMethodCallHandler { call, result -> EqChannel.handle(call, result) }
        // Home-screen widget feed (v2.31): Dart's WidgetSync
        // pushes song/lyrics/play-state; the provider renders.
        // v2.34: the channel is kept in a field so onNewIntent
        // can push widget transport actions into Dart, and Dart
        // can collect a cold-start action via takeWidgetAction.
        val wch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/widget")
        widgetChannel = wch
        wch.setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        DhunnWidgetProvider.storeAndRefresh(applicationContext, args)
                    }
                    result.success(null)
                } else if (call.method == "takeWidgetAction") {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
                } else {
                    result.notImplemented()
                }
            }
        // System info/actions for Drive Mode + the Connect-device
        // sheet (v2.33): keep-screen-on flag, Wi-Fi / Bluetooth
        // radio state, paired Bluetooth devices, settings panels.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/sys")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepScreenOn" -> {
                        val on = call.arguments as? Boolean ?: false
                        runOnUiThread {
                            if (on) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    "wifiEnabled" -> {
                        val wm = applicationContext.getSystemService(WIFI_SERVICE) as? android.net.wifi.WifiManager
                        @Suppress("DEPRECATION")
                        result.success(wm?.isWifiEnabled ?: false)
                    }
                    "bluetoothEnabled" -> {
                        @Suppress("DEPRECATION")
                        val ad = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                        result.success(ad?.isEnabled ?: false)
                    }
                    "pairedDevices" -> {
                        thread {
                            val list = mutableListOf<Map<String, String>>()
                            try {
                                @Suppress("DEPRECATION")
                                val ad = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
                                if (ad != null && ad.isEnabled) {
                                    for (d in ad.bondedDevices ?: emptySet()) {
                                        list.add(mapOf(
                                            "name" to (try { d.name ?: "" } catch (e: SecurityException) { "" }),
                                            "address" to (d.address ?: "")))
                                    }
                                }
                            } catch (e: Exception) { /* permission denied etc. */ }
                            Handler(Looper.getMainLooper()).post { result.success(list) }
                        }
                    }
                    "openWifi" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= 29) {
                                @Suppress("DEPRECATION")
                                startActivityForResult(
                                    android.content.Intent(android.provider.Settings.Panel.ACTION_WIFI), 4720)
                            } else {
                                startActivity(android.content.Intent(
                                    android.provider.Settings.ACTION_WIFI_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            }
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }
                    "openBluetooth" -> {
                        try {
                            startActivity(android.content.Intent(
                                android.provider.Settings.ACTION_BLUETOOTH_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) { result.success(false) }
                    }
                    else -> result.notImplemented()
                }
            }
        // Beat feed for the Fluid Beat background (v2.12): Visualizer
        // FFT bass energy on the player's audio session.
        io.flutter.plugin.common.EventChannel(
            flutterEngine.dartExecutor.binaryMessenger, "nova/viz"
        ).setStreamHandler(VizChannel())

        // Monetag interstitials (v2.25; Dart side in
        // services/ads.dart decides IF/WHEN — this side only shows).
        // The delivered zone is a JS-SDK zone (libtl.com), so the
        // show runs in MonetagAdActivity's full-screen WebView and
        // the result arrives via onActivityResult (request 4716).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/ads")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showInterstitial" -> {
                        val zone = call.arguments as? String ?: ""
                        if (zone.isEmpty() || adsResult != null) {
                            result.success(false)
                        } else {
                            adsResult = result
                            val intent = Intent(this, MonetagAdActivity::class.java)
                                .putExtra("zone", zone)
                            startActivityForResult(intent, 4716)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Progress notifications for the bulk HD-cover job (v2.19):
        // posted natively so NO extra Dart plugin is needed (size).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/notify")
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val ch = android.app.NotificationChannel(
                        "dhunn_progress", "Downloads & progress",
                        android.app.NotificationManager.IMPORTANCE_LOW)
                    nm.createNotificationChannel(ch)
                }
                val nid = call.argument<Int>("id") ?: 7001
                fun builder(): android.app.Notification.Builder {
                    val b = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
                        android.app.Notification.Builder(this, "dhunn_progress")
                    else @Suppress("DEPRECATION") android.app.Notification.Builder(this)
                    return b.setContentTitle(call.argument<String>("title") ?: "Dhunn")
                        .setContentText(call.argument<String>("text") ?: "")
                }
                when (call.method) {
                    "progress" -> {
                        val d = call.argument<Int>("done") ?: 0
                        val t = call.argument<Int>("total") ?: 0
                        val b = builder()
                            .setSmallIcon(android.R.drawable.stat_sys_download)
                            .setOngoing(true)
                            .setOnlyAlertOnce(true)
                        if (t > 0) b.setProgress(t, d, false)
                        nm.notify(nid, b.build())
                        result.success(null)
                    }
                    "done" -> {
                        nm.notify(nid, builder()
                            .setSmallIcon(android.R.drawable.stat_sys_download_done)
                            .setOngoing(false)
                            .build())
                        result.success(null)
                    }
                    "cancel" -> { nm.cancel(nid); result.success(null) }
                    "alert" -> {
                        // New-song alerts (v2.21): own channel with
                        // DEFAULT importance so the user SEES it.
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            val ach = android.app.NotificationChannel(
                                "dhunn_alerts", "New songs",
                                android.app.NotificationManager.IMPORTANCE_DEFAULT)
                            nm.createNotificationChannel(ach)
                        }
                        val launch = android.app.PendingIntent.getActivity(
                            this, 0,
                            android.content.Intent(this, MainActivity::class.java),
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                                android.app.PendingIntent.FLAG_IMMUTABLE)
                        val ab = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
                            android.app.Notification.Builder(this, "dhunn_alerts")
                        else @Suppress("DEPRECATION") android.app.Notification.Builder(this)
                        nm.notify(nid, ab
                            .setContentTitle(call.argument<String>("title") ?: "Dhunn")
                            .setContentText(call.argument<String>("text") ?: "")
                            .setSmallIcon(applicationInfo.icon)
                            .setContentIntent(launch)
                            .setAutoCancel(true)
                            .build())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/media")
            .setMethodCallHandler { call, result ->
                if (call.method == "filesDir") {
                    result.success(filesDir.absolutePath)
                } else if (call.method == "batteryExempt") {
                    // Background-stop fix (v2.19.1): is Dhunn exempt
                    // from battery optimisation?
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                } else if (call.method == "requestBatteryExempt") {
                    try {
                        startActivity(android.content.Intent(
                            android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            android.net.Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            startActivity(android.content.Intent(
                                android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        } catch (e2: Exception) { result.success(false) }
                    }
                } else if (call.method == "openAutoStart") {
                    // Vendor auto-start screens (OPPO/ColorOS, vivo,
                    // Xiaomi): without auto-start these phones kill
                    // background music. First resolvable wins; the
                    // fallback is this app's system settings page.
                    val candidates = listOf(
                        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                        "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
                        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    var opened = false
                    for ((pkg, cls) in candidates) {
                        try {
                            val intent = android.content.Intent()
                                .setClassName(pkg, cls)
                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent); opened = true; break
                            }
                        } catch (e: Exception) { /* try the next vendor */ }
                    }
                    if (!opened) {
                        try {
                            startActivity(android.content.Intent(
                                android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:$packageName"))
                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
                            opened = true
                        } catch (e: Exception) { }
                    }
                    result.success(opened)
                } else if (call.method == "setIcon") {
                    // Switch the LAUNCHER icon variant via the
                    // activity-alias set (v2.18). Enable the target
                    // FIRST so the app never has zero launchers.
                    val variant = call.argument<Int>("variant") ?: 0
                    try {
                        val pm = packageManager
                        val names = listOf(
                            "$packageName.MainActivity",
                            "$packageName.IconOcean",
                            "$packageName.IconSunset",
                            "$packageName.IconViolet")
                        val target = names[variant.coerceIn(0, 3)]
                        pm.setComponentEnabledSetting(
                            android.content.ComponentName(packageName, target),
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            android.content.pm.PackageManager.DONT_KILL_APP)
                        for (n in names) {
                            if (n != target) {
                                pm.setComponentEnabledSetting(
                                    android.content.ComponentName(packageName, n),
                                    android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    android.content.pm.PackageManager.DONT_KILL_APP)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else if (call.method == "openUrl") {
                    // Open an external link (update download page) in
                    // the browser — used by the GitHub update checker.
                    val u = call.argument<String>("url")
                    if (u == null) {
                        result.error("BAD_ARGS", "url missing", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                } else if (call.method == "downloadCover") {
                    // Download a high-quality cover image into
                    // filesDir/covers (called by CoverService).
                    val url = call.argument<String>("url")
                    val name = call.argument<String>("name")
                    if (url == null || name == null) {
                        result.error("BAD_ARGS", "url/name missing", null)
                    } else {
                        thread {
                            try {
                                val dir = File(filesDir, "covers").apply { mkdirs() }
                                val out = File(dir, name)
                                val conn = java.net.URL(url).openConnection() as java.net.HttpURLConnection
                                conn.connectTimeout = 15000
                                conn.readTimeout = 20000
                                conn.setRequestProperty("User-Agent", "HamzaPlayer/2.8 (Android)")
                                conn.instanceFollowRedirects = true
                                conn.inputStream.use { ins ->
                                    out.outputStream().use { os -> ins.copyTo(os) }
                                }
                                val ok = out.exists() && out.length() > 8000
                                Handler(Looper.getMainLooper()).post {
                                    if (ok) result.success(out.absolutePath)
                                    else { out.delete(); result.success(null) }
                                }
                            } catch (e: Exception) {
                                Handler(Looper.getMainLooper()).post { result.success(null) }
                            }
                        }
                    }
                } else if (call.method == "scanMedia") {
                    // Scanning + thumbnail generation is IO work — keep it
                    // off the main thread.
                    thread {
                        try {
                            val res = mapOf("audio" to scanAudio(), "video" to emptyList<Map<String, Any?>>())
                            Handler(Looper.getMainLooper()).post { result.success(res) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SCAN_FAILED", e.message, null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /// Metadata for a song opened via a file-manager VIEW intent
    /// (v2.21). Returns the playable source (content URI string, or
    /// the real path for file:// URIs) plus title/artist/duration
    /// when the retriever can read them.
    private fun openedInfo(uri: Uri): Map<String, Any?> {
        val isFile = uri.scheme == "file"
        val path = if (isFile) (uri.path ?: "") else ""
        val source = if (isFile) path else uri.toString()
        var display = ""
        if (!isFile) {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    val ni = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (c.moveToFirst() && ni >= 0) display = c.getString(ni) ?: ""
                }
            } catch (e: Exception) { }
        }
        if (display.isEmpty() && path.isNotEmpty()) display = File(path).name
        var title = ""
        var artist = ""
        var duration = 0L
        try {
            val r = android.media.MediaMetadataRetriever()
            if (isFile) r.setDataSource(path) else r.setDataSource(this, uri)
            title = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            artist = r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""
            duration = (r.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION) ?: "0").toLongOrNull() ?: 0L
            r.release()
        } catch (e: Exception) { }
        if (title.isEmpty()) title = display.replace(Regex("\\.[^.]+$"), "")
        return mapOf("source" to source, "path" to path, "title" to title,
            "artist" to artist, "duration" to duration)
    }

    /// Cached JPEG thumbnail for a MediaStore item (album art for audio,
    /// frame thumbnail for video). Fallback chain, because loadThumbnail
    /// fails for some files/devices:
    ///   1. ContentResolver.loadThumbnail (API 29+)
    ///   2. MediaMetadataRetriever — video frame at 1s / embedded picture
    /// Generated once, cached in cacheDir/thumbs, reused on later scans.
    /// Returns the file path or null. Flutter renders these via
    /// Image.file — content:// art URIs cannot be rendered by widgets.
    private fun thumbFor(kind: String, id: Long, contentUri: android.net.Uri, path: String): String? {
        val dir = File(cacheDir, "thumbs").apply { mkdirs() }
        // Audio art is generated at 800px since v2.8 (was 288px and
        // looked soft on the Now Playing screen) — the _hq suffix
        // keeps stale low-res cache files from being reused.
        val f = File(dir, if (kind == "audio") "audio_${id}_hq.jpg" else "${kind}_$id.jpg")
        if (f.exists() && f.length() > 0) return f.absolutePath
        // 1) MediaStore thumbnail
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                val bmp: Bitmap = contentResolver.loadThumbnail(contentUri, Size(800, 800), null)
                FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, 88, it) }
                bmp.recycle()
                if (f.length() > 0) return f.absolutePath
            } catch (e: Exception) {
                // fall through to retriever
            }
        }
        // 2) MediaMetadataRetriever on the real file
        if (path.isNotEmpty()) {
            try {
                val r = android.media.MediaMetadataRetriever()
                r.setDataSource(path)
                if (kind == "video") {
                    val bmp = r.getFrameAtTime(1000000, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                    if (bmp != null) {
                        FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                        bmp.recycle()
                    }
                } else {
                    val pic = r.embeddedPicture
                    if (pic != null) f.writeBytes(pic)
                }
                r.release()
                if (f.length() > 0) return f.absolutePath
            } catch (e: Exception) {
                // give up on this item — UI shows a gradient placeholder
            }
        }
        return null
    }

    private fun scanAudio(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val proj = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ALBUM_ID,
            if (Build.VERSION.SDK_INT >= 29) MediaStore.Audio.Media.RELATIVE_PATH else MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DATA
        )
        contentResolver.query(uri, proj, "${MediaStore.Audio.Media.IS_MUSIC} != 0", null,
            "${MediaStore.Audio.Media.TITLE} ASC")?.use { c ->
            val idI = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleI = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistI = c.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumI = c.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durI = c.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val sizeI = c.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val dateI = c.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val albumIdI = c.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val dataI = c.getColumnIndex(MediaStore.Audio.Media.DATA)
            while (c.moveToNext()) {
                val albumId = if (albumIdI >= 0) c.getLong(albumIdI) else 0L
                val artUri = if (albumId > 0)
                    ContentUris.withAppendedId(
                        android.net.Uri.parse("content://media/external/audio/albumart"), albumId
                    ).toString() else null
                val rowId = c.getLong(idI)
                val contentUriObj = ContentUris.withAppendedId(uri, rowId)
                val contentUri = contentUriObj.toString()
                out.add(mapOf(
                    "uri" to contentUri,
                    "thumb" to thumbFor("audio", rowId, contentUriObj,
                        if (dataI >= 0) c.getString(dataI) ?: "" else ""),
                    "id" to "audio_${c.getLong(idI)}",
                    "title" to (c.getString(titleI) ?: "Unknown"),
                    "artist" to (if (artistI >= 0) c.getString(artistI) ?: "" else ""),
                    "album" to (if (albumI >= 0) c.getString(albumI) ?: "" else ""),
                    "duration" to (if (durI >= 0) c.getLong(durI) else 0L),
                    "size" to (if (sizeI >= 0) c.getLong(sizeI) else 0L),
                    "dateAdded" to (if (dateI >= 0) c.getLong(dateI) else 0L),
                    "artUri" to artUri,
                    "path" to (if (dataI >= 0) c.getString(dataI) ?: "" else "")
                ))
            }
        }
        return out
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 4716) {
            val res = adsResult; adsResult = null
            if (res == null) return
            val shown = data?.getBooleanExtra("shown", false) ?: false
            res.success(shown && resultCode == RESULT_OK)
            return
        }
        if (requestCode == 4715) {
            val res = folderPickResult; folderPickResult = null
            if (res == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { res.success(null); return }
            try {
                val treeId = android.provider.DocumentsContract.getTreeDocumentId(uri)
                val parts = treeId.split(":", limit = 2)
                val sub = if (parts.size > 1) parts[1] else ""
                val path = when (parts[0]) {
                    "primary" -> {
                        val root = android.os.Environment.getExternalStorageDirectory().absolutePath
                        if (sub.isEmpty()) root else "$root/$sub"
                    }
                    "raw" -> sub
                    else -> if (sub.isEmpty()) "/storage/${parts[0]}" else "/storage/${parts[0]}/$sub"
                }
                res.success(path)
            } catch (t: Throwable) {
                res.success(null)
            }
            return
        }
        if (requestCode == 4714) {
            val res = textPickResult; textPickResult = null
            if (res == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { res.success(null); return }
            Thread {
                try {
                    val out = java.io.File(filesDir, "lyrics_pick.txt")
                    contentResolver.openInputStream(uri)?.use { input ->
                        out.outputStream().use { input.copyTo(it) }
                    }
                    runOnUiThread { res.success(out.absolutePath) }
                } catch (t: Throwable) {
                    runOnUiThread { res.success(null) }
                }
            }.start()
            return
        }
        if (requestCode == 4713) {
            val res = bgPickResult; bgPickResult = null
            if (res == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { res.success(null); return }
            Thread {
                try {
                    val out = java.io.File(filesDir, "player_bg.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        out.outputStream().use { input.copyTo(it) }
                    }
                    runOnUiThread { res.success(out.absolutePath) }
                } catch (t: Throwable) {
                    runOnUiThread { res.success(null) }
                }
            }.start()
        }
    }
}
