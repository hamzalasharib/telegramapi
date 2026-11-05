"""TV channels API — public iptv-org Pakistan playlist as JSON.

GET /api/tv returns {success, count, channels: [{name, logo, group, url}]}
Source: the public iptv-org country list for Pakistan (the same public
source the legal Hamza TV app uses). Parsed server-side and cached by
the CDN header, so the app and site share one channel list.
"""
import json, urllib.request
from http.server import BaseHTTPRequestHandler

PLAYLIST = "https://iptv-org.github.io/iptv/countries/pk.m3u"

def parse_m3u(text):
    channels, meta = [], None
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXTINF"):
            meta = {"logo": "", "group": "", "name": ""}
            if 'tvg-logo="' in line:
                meta["logo"] = line.split('tvg-logo="', 1)[1].split('"', 1)[0]
            if 'group-title="' in line:
                meta["group"] = line.split('group-title="', 1)[1].split('"', 1)[0]
            meta["name"] = line.rsplit(",", 1)[-1].strip()
        elif line and not line.startswith("#") and meta is not None:
            meta["url"] = line
            channels.append(meta)
            meta = None
    return channels

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        req = urllib.request.Request(PLAYLIST, headers={"User-Agent": "HamzaEditz/1.0"})
        try:
            with urllib.request.urlopen(req, timeout=25) as r:
                text = r.read().decode("utf-8", "ignore")
            channels = parse_m3u(text)
            return self._send({"success": True, "source": "iptv-org (public)", "count": len(channels), "channels": channels})
        except Exception as e:
            return self._send({"success": False, "message": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "public, max-age=21600")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
