"""Instagram downloader API — mirrors the page's codetabs->snapdownloader
route server-side and returns the result page HTML (instagram.html keeps
its own parser). GET /api/instagram?quest=<snapdownloader url>
Tries the target directly first, then via the codetabs proxy.
"""
import urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        target = (qs.get("quest") or [""])[0].strip()
        if not target.startswith("https://snapdownloader.com/"):
            return self._send("bad target", 400)
        last_err = None
        for url in (target, "https://api.codetabs.com/v1/proxy?quest=" + urllib.parse.quote(target, safe="")):
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
            try:
                with urllib.request.urlopen(req, timeout=25) as r:
                    html = r.read().decode("utf-8", "ignore")
                if html and len(html) > 200:
                    return self._send(html, 200)
            except Exception as e:
                last_err = e
        return self._send("Upstream error: %s" % last_err, 502)

    def _send(self, text, status):
        body = text.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
