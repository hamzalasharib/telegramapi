"""Vercel serverless proxy for the Spotify downloader (spotsaver.net API).
The browser pipeline broke because corsproxy.io now needs a paid key and
spotsaver rejects foreign-Origin POSTs. Server-side calls have neither
problem. Browser -> /api/spot {step, ...} -> spotsaver.net"""
import json, urllib.request, urllib.error, urllib.parse
from http.server import BaseHTTPRequestHandler

API = "https://spotsaver.net/api/"

def call(method, path, payload=None, params=None):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(url, data=data, method=method,
        headers={"Content-Type": "application/json",
                 "Accept": "application/json",
                 "User-Agent": "Mozilla/5.0 (HamzaEditz)"})
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8", "ignore"))

class handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length", 0))
            req = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._send(400, {"error": "Bad request"})
        step = req.get("step")
        try:
            if step == "spotify":
                return self._send(200, call("GET", "spotify/", params={"url": req.get("url", "")}))
            if step == "get-id":
                return self._send(200, call("POST", "get-id/", {"title": req.get("title", ""), "artist": req.get("artist", "")}))
            if step == "download":
                return self._send(200, call("POST", "download/", {
                    "videoId": req.get("videoId"), "candidateIds": req.get("candidateIds", []),
                    "format": req.get("format", "mp3"), "title": req.get("title", ""),
                    "licenseKey": req.get("licenseKey")}))
            return self._send(400, {"error": "Unknown step"})
        except urllib.error.HTTPError as e:
            try:
                return self._send(200, json.loads(e.read().decode("utf-8", "ignore")))
            except Exception:
                return self._send(502, {"error": f"Upstream {e.code}"})
        except Exception as e:
            return self._send(502, {"error": f"Upstream unreachable: {str(e)[:80]}"})

    def do_GET(self):
        return self._send(405, {"error": "POST only"})

    def log_message(self, *args):
        pass
