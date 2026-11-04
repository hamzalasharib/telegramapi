"""Vercel serverless proxy for the Jazz Shake N Win Claimer API (by WASIF ALI).
Browser -> /api/jazz {ep, payload} -> https://wasifali.biz.id/jazz-claimer/api/<ep>
Same-origin, so no CORS problem."""
import json, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler

BASE = "https://wasifali.biz.id/jazz-claimer/api/"
ALLOWED = {"ping", "send_otp", "verify_otp", "check_rewards", "claim_reward",
           "my_numbers", "toggle_auto_claim", "logout", "rewards_list"}

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
            return self._send(400, {"success": False, "message": "Bad request"})
        ep = str(req.get("ep", ""))
        if ep not in ALLOWED:
            return self._send(400, {"success": False, "message": "Unknown endpoint"})
        payload = req.get("payload") or {}
        try:
            r = urllib.request.Request(
                BASE + ep,
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json",
                         "User-Agent": "HamzaEditz/1.0"},
                method="POST")
            with urllib.request.urlopen(r, timeout=40) as resp:
                data = json.loads(resp.read().decode("utf-8", "ignore"))
            return self._send(200, data)
        except urllib.error.HTTPError as e:
            try:
                return self._send(200, json.loads(e.read().decode("utf-8", "ignore")))
            except Exception:
                return self._send(200, {"success": False, "message": f"API error {e.code}"})
        except Exception as e:
            return self._send(200, {"success": False, "message": f"API unreachable: {str(e)[:80]}"})

    def do_GET(self):
        return self._send(405, {"success": False, "message": "POST only"})

    def log_message(self, *args):
        pass
