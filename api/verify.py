"""Vercel serverless proxy for Punjab Domicile verification.
Mirrors the user's Flask logic: session GET on domicile.punjab.gov.pk,
then AjaxCall.aspx?ID=<cnic>, parse the result spans, return JSON.
Browser -> /api/verify {cnic} (same-origin, no CORS problem)."""
import json, re, urllib.request, urllib.error, http.cookiejar
from http.server import BaseHTTPRequestHandler

BASE = "https://domicile.punjab.gov.pk"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Mobile Safari/537.36",
    "x-requested-with": "XMLHttpRequest",
    "Accept": "text/html, */*; q=0.01",
    "Referer": BASE + "/",
    "Accept-Language": "en-GB,en-US;q=0.9,en;q=0.8",
}

def parse_domicile(html):
    def g(i):
        m = re.search(r'<span[^>]*id="%s"[^>]*>(.*?)</span>' % re.escape(i), html, re.DOTALL | re.I)
        return re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""
    name = g("lblName")
    if not name:
        return None
    return {"name": name, "father": g("lblGaudain2"), "district": g("lblDistrict"),
            "tehsil": g("lblTehsil"), "status": g("lblStatus"),
            "submission_date": g("lblSubmissionDate")}

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
            return self._send(400, {"success": False, "error": "Bad request"})
        cnic = re.sub(r"\D", "", str(req.get("cnic", "")))
        if len(cnic) != 13:
            return self._send(200, {"success": False, "error": "CNIC 13 digits ka hona chahiye"})
        try:
            cj = http.cookiejar.CookieJar()
            opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
            try:
                opener.open(urllib.request.Request(BASE + "/", headers=HEADERS), timeout=20).read()
            except Exception:
                pass
            r = opener.open(urllib.request.Request(f"{BASE}/AjaxCall.aspx?ID={cnic}", headers=HEADERS), timeout=30)
            html = r.read().decode("utf-8", "ignore")
            info = parse_domicile(html)
            if not info:
                return self._send(200, {"success": False, "error": "Iss CNIC ka record nahi mila"})
            return self._send(200, {"success": True, "data": info,
                                    "cnic": f"{cnic[:5]}-{cnic[5:12]}-{cnic[12]}"})
        except Exception as e:
            return self._send(200, {"success": False, "error": f"Server error: {str(e)[:100]}"})

    def do_GET(self):
        return self._send(405, {"success": False, "error": "POST only"})

    def log_message(self, *args):
        pass
