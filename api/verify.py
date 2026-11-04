"""Punjab Domicile verification — multi-route edition.
domicile.punjab.gov.pk refuses or times out most datacenter IPs, so this
function tries several routes in turn: Google Translate's fetcher,
allorigins, then a direct session call (the user's original Flask logic).
First route that returns the portal's result page wins.
Browser -> POST /api/verify {cnic}"""
import json, re, urllib.request, urllib.error, urllib.parse, http.cookiejar
from http.server import BaseHTTPRequestHandler

BASE = "https://domicile.punjab.gov.pk"
UA = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Mobile Safari/537.36"
HEADERS = {"User-Agent": UA, "x-requested-with": "XMLHttpRequest",
           "Accept": "text/html, */*; q=0.01", "Referer": BASE + "/",
           "Accept-Language": "en-GB,en-US;q=0.9,en;q=0.8"}

def parse_domicile(html):
    def g(i):
        m = re.search(r'<span[^>]*id="%s"[^>]*>(.*?)</span>' % re.escape(i), html, re.DOTALL | re.I)
        return re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""
    if "lblName" not in html:
        return None, False
    name = g("lblName")
    info = {"name": name, "father": g("lblGaudain2"), "district": g("lblDistrict"),
            "tehsil": g("lblTehsil"), "status": g("lblStatus"),
            "submission_date": g("lblSubmissionDate")}
    return info, bool(name)

def fetch(url, headers=None, timeout=22, opener=None):
    req = urllib.request.Request(url, headers=headers or {"User-Agent": UA})
    o = opener or urllib.request.build_opener()
    with o.open(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "ignore")

def route_translate(cnic):
    u = ("https://domicile-punjab-gov-pk.translate.goog/AjaxCall.aspx?ID=%s"
         "&_x_tr_sl=ur&_x_tr_tl=en&_x_tr_hl=en" % cnic)
    return fetch(u, {"User-Agent": UA, "Accept": "text/html"})

def route_allorigins(cnic):
    target = "%s/AjaxCall.aspx?ID=%s" % (BASE, cnic)
    return fetch("https://api.allorigins.win/raw?url=" + urllib.parse.quote(target, safe=""),
                 {"User-Agent": UA})

def route_direct(cnic):
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    try:
        fetch(BASE + "/", HEADERS, timeout=12, opener=opener)
    except Exception:
        pass
    return fetch("%s/AjaxCall.aspx?ID=%s" % (BASE, cnic), HEADERS, timeout=22, opener=opener)

ROUTES = [route_translate, route_allorigins, route_direct]

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
        reached = False
        for route in ROUTES:
            try:
                html = route(cnic)
            except Exception:
                continue
            if not html:
                continue
            info, has_name = parse_domicile(html)
            if info is None:
                continue  # not the portal's result page (error/redirect page)
            reached = True
            if has_name:
                return self._send(200, {"success": True, "data": info,
                                        "cnic": f"{cnic[:5]}-{cnic[5:12]}-{cnic[12]}"})
            break  # portal answered and the record is genuinely absent
        if reached:
            return self._send(200, {"success": False, "error": "Iss CNIC ka record nahi mila"})
        return self._send(200, {"success": False,
                                "error": "Portal busy/slow hai — aik dafa dobara try karo, aksar doosri try par record aa jata hai"})

    def do_GET(self):
        return self._send(405, {"success": False, "error": "POST only"})

    def log_message(self, *args):
        pass
