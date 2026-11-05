"""Tools catalog API — the app-ready index of hamzaeditz.tech.

GET /api/tools returns every tool as clean JSON (name, short description,
page URL, icon, colours, whether it has its own API). A future HamzaEditz
app builds its home screen straight from this list; the website and the
app stay in sync because both read the same source of truth.
"""
import json
from http.server import BaseHTTPRequestHandler

BASE = "https://hamzaeditz.tech/"
TOOLS = [
    {"id": "dhunn", "name": "Dhunn Music Player", "desc": "Music player with synced lyrics, art designs and themes.",
     "page": "dhunn.html", "icon": "music", "colors": ["#f59e0b", "#8b5cf6"], "new": True, "api": None},
    {"id": "rdp-latest", "name": "New RDP — Latest Method", "desc": "Latest free RDP method — video guide and ready-made code.",
     "page": "rdp-latest.html", "icon": "monitor", "colors": ["#8b5cf6", "#ec4899"], "new": True, "api": None},
    {"id": "domicile", "name": "Domicile Verify", "desc": "Check a Punjab domicile record by CNIC.",
     "page": "domicile.html", "icon": "shield", "colors": ["#22c55e", "#84cc16"], "new": True, "api": "/api/verify"},
    {"id": "jazz-claimer", "name": "Jazz Shake N Win Claimer", "desc": "Claim daily Jazz Shake N Win rewards with OTP login.",
     "page": "jazz-claimer.html", "icon": "zap", "colors": ["#ef4444", "#f97316"], "new": True, "api": "/api/jazz"},
    {"id": "tiktok", "name": "TikTok Downloader", "desc": "Download TikTok videos without watermark.",
     "page": "tiktokmenu.html", "icon": "download", "colors": ["#ec4899", "#8b5cf6"], "new": False, "api": "/api/tiktok"},
    {"id": "spotify", "name": "Spotify Downloader", "desc": "Convert Spotify tracks to MP3.",
     "page": "spotify.html", "icon": "music", "colors": ["#22c55e", "#0ea5e9"], "new": False, "api": "/api/spot"},
    {"id": "image", "name": "AI Image Generator", "desc": "Generate AI images from a text prompt.",
     "page": "image.html", "icon": "image", "colors": ["#f43f5e", "#f59e0b"], "new": False, "api": "/api/image"},
    {"id": "tv", "name": "Jazz TV", "desc": "Watch live TV channels.",
     "page": "TvChannels.html", "icon": "tv", "colors": ["#10b981", "#84cc16"], "new": False, "api": None},
    {"id": "hadith", "name": "Hadith Collection", "desc": "Search Hadith by book and chapter.",
     "page": "hadith.html", "icon": "book", "colors": ["#eab308", "#f97316"], "new": False, "api": "/api/hadith"},
    {"id": "rdp", "name": "Free Windows RDP", "desc": "Step-by-step guide for a free Windows RDP.",
     "page": "RdpMethod.html", "icon": "monitor", "colors": ["#8b5cf6", "#ec4899"], "new": False, "api": None},
    {"id": "sms", "name": "SMS Tool", "desc": "Fast SMS utility.",
     "page": "smsbomber.html", "icon": "send", "colors": ["#f97316", "#ef4444"], "new": False, "api": None},
    {"id": "about", "name": "About the Creator", "desc": "About Hamza Shafiq.",
     "page": "about.html", "icon": "user", "colors": ["#0ea5e9", "#6366f1"], "new": False, "api": None},
]

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        tools = []
        for t in TOOLS:
            item = dict(t)
            item["url"] = BASE + t["page"]
            if t["api"]:
                item["api"] = BASE.rstrip("/") + t["api"]
            tools.append(item)
        body = json.dumps({
            "success": True,
            "app": {"name": "HamzaEditz", "version": 1},
            "count": len(tools),
            "tools": tools,
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "public, max-age=3600")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
