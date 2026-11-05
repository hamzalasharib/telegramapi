"""AI image generator API for image.html.

The old upstream (famofc.site) is dead — its domain expired (verified
2026-11-05: HTTPS rejects the handshake, HTTP serves a parked-domain
page). New upstream: Pollinations (free, no key) — the same service the
Telegram quotes pipeline uses. The function verifies generation
server-side, then returns the page's expected shape:
{success: true, images: [{image_url, prompt, id}]}
GET /api/image?prompt=<text>&aspectRatio=<square|landscape|portrait>
"""
import json, random, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

SIZES = {"square": (1024, 1024), "landscape": (1280, 720), "portrait": (720, 1280)}

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        prompt = (qs.get("prompt") or [""])[0].strip()
        ratio = (qs.get("aspectRatio") or ["square"])[0].strip().lower()
        if not prompt:
            return self._send({"success": False, "message": "Missing prompt"})
        w, h = SIZES.get(ratio, SIZES["square"])
        seed = random.randint(1, 999999)
        url = ("https://image.pollinations.ai/prompt/" + urllib.parse.quote(prompt)
               + "?width=%d&height=%d&nologo=true&seed=%d" % (w, h, seed))
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (HamzaEditz)"})
        try:
            with urllib.request.urlopen(req, timeout=50) as r:
                ctype = r.headers.get_content_type() or ""
                r.read()
            if not ctype.startswith("image/"):
                return self._send({"success": False, "message": "Generator did not return an image"}, 502)
            return self._send({"success": True, "images": [{"image_url": url, "prompt": prompt, "id": seed}]})
        except Exception as e:
            return self._send({"success": False, "message": "Generator error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
