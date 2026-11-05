"""Quran API for QURAN.html — forwards to the official AlQuran Cloud API.

GET /api/quran?path=<surah | surah/114 | surah/1/en.asad | ...>
Returns the upstream JSON unchanged.
"""
import json, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        path = (qs.get("path") or ["surah"])[0].strip().lstrip("/")
        if ".." in path:
            return self._send({"code": 400, "status": "error", "data": "bad path"}, 400)
        api = "https://api.alquran.cloud/v1/" + urllib.parse.quote(path, safe="/.")
        req = urllib.request.Request(api, headers={"User-Agent": "HamzaEditz/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
            return self._send(data)
        except Exception as e:
            return self._send({"code": 502, "status": "error", "data": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "public, max-age=86400")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
