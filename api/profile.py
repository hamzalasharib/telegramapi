"""TikTok profile API for user.html — forwards to the profile worker API.

GET /api/profile?username=<name> → the worker's JSON, unchanged.
"""
import json, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        username = (qs.get("username") or [""])[0].strip().lstrip("@")
        if not username:
            return self._send({"status": "error", "message": "Missing username"})
        api = "https://tiktokinfov10.itfreeforever.workers.dev/?username=" + urllib.parse.quote(username)
        req = urllib.request.Request(api, headers={"User-Agent": "Mozilla/5.0 (HamzaEditz)"})
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
            return self._send(data)
        except Exception as e:
            return self._send({"status": "error", "message": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
