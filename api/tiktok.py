"""TikTok downloader API for tiktok.html — forwards to tikwm.com server-side.

GET /api/tiktok?url=<tiktok video url>
Returns the tikwm JSON unchanged ({code: 0, data: {...}}) so the page and a
future app share one contract. On upstream failure: {code: -1, msg: ...}.
"""
import json, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        url = (qs.get("url") or [""])[0].strip()
        if not url:
            return self._send({"code": -1, "msg": "Missing url parameter"})
        api = "https://www.tikwm.com/api/?url=" + urllib.parse.quote(url, safe="")
        req = urllib.request.Request(api, headers={"User-Agent": "Mozilla/5.0 (HamzaEditz)"})
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
            return self._send(data)
        except Exception as e:
            return self._send({"code": -1, "msg": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
