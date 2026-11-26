"""MovieBox play proxy for movie.html — returns REAL stream URLs.

GET /api/movieplay?subjectId=<id>&se=<season>&ep=<episode>&detailPath=<slug>

Why this exists: the MovieBox play endpoint
  GET https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play
only returns streams (data.streams[] = signed MP4s per resolution,
data.dash[] = DASH manifests) when the request carries the play page's
Referer (https://mzfi.me/spa/videoPlayPage/movies/<detailPath>). A browser
on hamzaeditz.tech cannot set that Referer, so this function makes the
call server-side and passes the upstream JSON through unchanged.

Movies use se=0&ep=0; series use se=<season>&ep=<episode>.
On upstream failure: {code: -1, msg: ...}.
"""
import json, re, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

API = "https://h5-api.aoneroom.com/wefeed-h5api-bff"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0 Safari/537.36")


def _get(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=25) as r:
        return r


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        subject_id = (qs.get("subjectId") or [""])[0].strip()
        detail_path = (qs.get("detailPath") or [""])[0].strip()
        try:
            se = int((qs.get("se") or ["0"])[0])
            ep = int((qs.get("ep") or ["0"])[0])
        except ValueError:
            return self._send({"code": -1, "msg": "se/ep must be numbers"}, 400)
        if not re.fullmatch(r"\d{5,25}", subject_id):
            return self._send({"code": -1, "msg": "Missing/invalid subjectId"}, 400)
        if not re.fullmatch(r"[A-Za-z0-9\-]{3,120}", detail_path):
            return self._send({"code": -1, "msg": "Missing/invalid detailPath"}, 400)

        play_referer = "https://mzfi.me/spa/videoPlayPage/movies/" + detail_path
        try:
            # 1) fresh guest JWT from the x-user header of /home
            with _get(API + "/home", {"User-Agent": UA,
                                      "Referer": "https://themoviebox.xyz/"}) as r:
                xu = r.headers.get("x-user")
            token = json.loads(xu)["token"] if xu else ""
            # 2) the play call itself, with the play-page Referer
            q = urllib.parse.urlencode({
                "subjectId": subject_id, "se": se, "ep": ep,
                "detailPath": detail_path, "streamSignType": 1,
            })
            headers = {
                "User-Agent": UA,
                "Accept": "application/json",
                "Referer": play_referer,
                "X-Client-Info": json.dumps({"timezone": "Asia/Karachi"}),
                "X-Source": "",
            }
            if token:
                headers["Authorization"] = "Bearer " + token
            with _get(API + "/subject/play?" + q, headers) as r:
                data = json.loads(r.read().decode("utf-8", "ignore"))
            return self._send(data)
        except Exception as e:
            return self._send({"code": -1, "msg": "Upstream error: %s" % e}, 502)

    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass
