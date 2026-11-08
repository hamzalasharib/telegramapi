package com.novaplayer.nova_player

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView

/// Full-screen Monetag interstitial (v2.25). The zone the developer
/// received is a JS-SDK zone (libtl.com loader), so the ad runs in
/// this throwaway WebView activity: the loader script defines
/// `show_<zone>()`, we call it ONCE — manually, when Dart's
/// AdsService rules say so — and finish when its promise settles.
/// We deliberately do NOT use the SDK's `inApp` auto mode
/// (Monetag's own timer would show far more ads than our caps).
/// Every failure path finishes quietly with shown=false.
class MonetagAdActivity : Activity() {
    private var webView: WebView? = null
    private var finished = false
    private var adRequested = false
    private val handler = Handler(Looper.getMainLooper())

    inner class Bridge {
        @JavascriptInterface
        fun started() {
            adRequested = true
        }

        @JavascriptInterface
        fun done(shown: Boolean) {
            runOnUiThread { finishWith(shown) }
        }
    }

    private fun finishWith(shown: Boolean) {
        if (finished) return
        finished = true
        val data = Intent().putExtra("shown", shown)
        setResult(RESULT_OK, data)
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // If an ad is on screen, backing out counts as a view;
        // before that it is just a cancelled attempt.
        finishWith(adRequested)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try {
            webView?.destroy()
        } catch (_: Throwable) {
        }
        webView = null
        super.onDestroy()
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val zone = intent?.getStringExtra("zone") ?: ""
        if (zone.isEmpty()) {
            finishWith(false)
            return
        }
        val wv = WebView(this)
        webView = wv
        setContentView(wv)
        val s = wv.settings
        s.javaScriptEnabled = true
        s.domStorageEnabled = true
        s.mediaPlaybackRequiresUserGesture = false
        s.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        wv.addJavascriptInterface(Bridge(), "DhunnBridge")
        val html = """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>html,body{margin:0;padding:0;height:100%;background:#000}</style>
            <script src='https://libtl.com/sdk.js' data-zone='$zone' data-sdk='show_$zone'></script>
            </head><body><script>
            var tries = 0;
            var iv = setInterval(function() {
              tries++;
              var fn = window['show_$zone'];
              if (typeof fn === 'function') {
                clearInterval(iv);
                try {
                  DhunnBridge.started();
                  var p = fn();
                  if (p && p.then) {
                    p.then(function(){ DhunnBridge.done(true); })
                     .catch(function(){ DhunnBridge.done(false); });
                  } else { DhunnBridge.done(true); }
                } catch (e) { DhunnBridge.done(false); }
              } else if (tries > 40) {
                clearInterval(iv);
                DhunnBridge.done(false);
              }
            }, 300);
            </script></body></html>
        """.trimIndent()
        wv.loadDataWithBaseURL("https://libtl.com/", html, "text/html", "utf-8", null)
        // Safety net: never trap the user on a black screen.
        handler.postDelayed({ finishWith(adRequested) }, 90_000)
    }
}
