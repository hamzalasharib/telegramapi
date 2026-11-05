"""AI image generator API for image.html — forwards to famofc.site server-side.

GET /api/image?prompt=<text>&aspectRatio=<1:1|16:9|...>
Returns the upstream JSON unchanged ({success, images: [{image_url, ...}]}).
On upstream failure: {success: false, message: ...} (the page's own shape).
"""
import json, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        prompt = (qs.get("prompt") or [""])[0].strip()
        ratio = (qs.get("aspectRatio") or ["1:1"])[0].strip()
        if not prompt:
            return self._send({"success": False, "message": "Missing prompt"})
        api = ("https://famofc.site/api/generate.php?prompt=" + urllib.parse.quote(prompt)
               + "&aspectRatio=" + urllib.parse.quote(ratio))
        req = urllib.request.Request(api, headers={"User-Agent": "Mozilla/5.0 (HamzaEditz)"})
        try:
            with urllib.request.urlopen(req, timeout=55) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
            return self._send(data)
        except Exception as e:
            return self._send({"success": False, "message": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
