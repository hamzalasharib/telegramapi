"""MovieBox play proxy + media relay for movie.html.

JSON mode (default):
  GET /api/movieplay?subjectId=<id>&se=<season>&ep=<episode>&detailPath=<slug>
  -> the upstream subject/play JSON, unchanged (real stream URLs).

Relay modes (added because the hakunaymatata CDN refuses direct browser
playback from anywhere except the real mzfi.me player):
  GET /api/movieplay?mode=watch&subjectId&se&ep&detailPath&res=360
  -> fresh play call, pick the MP4 of that resolution (else nearest),
     fetch it server-side with the mzfi play-page Referer and relay the
     bytes back, honouring the browser's Range header (200/206).
  GET /api/movieplay?mode=dash&subjectId&se&ep&detailPath
  -> fetch the DASH manifest server-side with the item's sign header
     (real-player recipe: header named by signHeaderKey, e.g. X-MB-Token,
     value = signCookie) + play-page Referer, rewrite every media URL in
     it to mode=seg on this function, return application/dash+xml.
  GET /api/movieplay?mode=seg&ref=<detailPath>&hk=<headerName>&tok=<signValue>&u=<absolute segment URL>
  -> relay one DASH segment with the same sign header + Referer.

Why the JSON mode exists: the MovieBox play endpoint
  GET https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play
only returns streams when the request carries the play page's Referer
(https://mzfi.me/spa/videoPlayPage/movies/<detailPath>), which a browser
on hamzaeditz.tech cannot set — so all upstream calls happen here.

Movies use se=0&ep=0; series use se=<season>&ep=<episode>.
On upstream failure: {code: -1, msg: ...}.
"""
import json, re, urllib.request, urllib.parse, urllib.error
from http.server import BaseHTTPRequestHandler

API = "https://h5-api.aoneroom.com/wefeed-h5api-bff"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/131.0 Safari/537.36")
MEDIA_HOSTS = {"bcdnxw.hakunaymatata.com", "sbcdnw.hakunaymatata.com"}
CHUNK = 65536


def _get(url, headers, timeout=25):
    req = urllib.request.Request(url, headers=headers)
    return urllib.request.urlopen(req, timeout=timeout)


def _fetch_play(subject_id, se, ep, detail_path):
    """One fresh subject/play call. Returns the inner data dict."""
    play_referer = "https://mzfi.me/spa/videoPlayPage/movies/" + detail_path
    with _get(API + "/home", {"User-Agent": UA,
                              "Referer": "https://themoviebox.xyz/"}) as r:
        xu = r.headers.get("x-user")
    token = json.loads(xu)["token"] if xu else ""
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
        envelope = json.loads(r.read().decode("utf-8", "ignore"))
    return envelope


def _play_referer(detail_path):
    return "https://mzfi.me/spa/videoPlayPage/movies/" + detail_path


def _media_headers(detail_path, item=None, extra=None):
    h = {"User-Agent": UA, "Referer": _play_referer(detail_path),
         "Accept": "*/*"}
    if item:
        key = (item.get("signHeaderKey") or "").strip()
        val = (item.get("signCookie") or "").strip()
        if key and val and re.fullmatch(r"[!#$%&'*+\-.^_`|~0-9A-Za-z]+", key):
            h[key] = val
    if extra:
        h.update(extra)
    return h


class handler(BaseHTTPRequestHandler):
    # ---------- shared helpers ----------
    def _send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _relay(self, url, headers):
        """Fetch url server-side and stream status/headers/body back."""
        rng = self.headers.get("Range")
        if rng:
            headers["Range"] = rng
        try:
            resp = _get(url, headers, timeout=30)
        except urllib.error.HTTPError as e:
            body = ("Upstream CDN error: HTTP %d" % e.code).encode()
            try:
                self.send_response(e.code)
            except Exception:
                return
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        with resp:
            self.send_response(resp.status)
            for name in ("Content-Type", "Content-Length", "Content-Range",
                         "Accept-Ranges", "ETag", "Last-Modified"):
                v = resp.headers.get(name)
                if v:
                    self.send_header(name, v)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            while True:
                chunk = resp.read(CHUNK)
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    break

    # ---------- modes ----------
    def _mode_watch(self, p):
        try:
            res_want = int(p["res"])
        except (KeyError, ValueError):
            res_want = 0
        env = _fetch_play(p["subjectId"], p["se"], p["ep"], p["detailPath"])
        data = (env or {}).get("data") or {}
        streams = [s for s in (data.get("streams") or []) if s.get("url")]
        if not streams:
            return self._send_json(
                {"code": -1, "msg": "No streams in play response"}, 502)
        def _res(s):
            try:
                return int(s.get("resolutions") or 0)
            except (TypeError, ValueError):
                return 0
        pick = min(streams, key=lambda s: (abs(_res(s) - res_want), _res(s)))
        self._relay(pick["url"], _media_headers(p["detailPath"], pick))

    def _mode_dash(self, p):
        env = _fetch_play(p["subjectId"], p["se"], p["ep"], p["detailPath"])
        data = (env or {}).get("data") or {}
        items = [d for d in (data.get("dash") or []) if d.get("url")]
        if not items:
            return self._send_json(
                {"code": -1, "msg": "No DASH manifest in play response"}, 502)
        item = items[0]
        murl = item["url"]
        with _get(murl, _media_headers(p["detailPath"], item),
                  timeout=30) as r:
            text = r.read().decode("utf-8", "ignore")
        base = murl.rsplit("/", 1)[0] + "/"
        tok = urllib.parse.quote(item.get("signCookie") or "", safe="")
        hk = urllib.parse.quote(item.get("signHeaderKey") or "", safe="")
        ref = urllib.parse.quote(p["detailPath"], safe="")

        def seg_url(raw):
            raw = raw.strip()
            if not raw:
                return raw
            absu = raw if raw.startswith("http") else base + raw
            q = ("mode=seg&ref=" + ref + "&hk=" + hk + "&tok=" + tok +
                 "&u=" + urllib.parse.quote(absu, safe="$%"))
            return ("/api/movieplay?" + q).replace("&", "&amp;")

        def attr_sub(m):
            return m.group(1) + '="' + seg_url(m.group(2)) + '"'
        text = re.sub(r'\b(media|initialization|sourceURL)="([^"]+)"',
                      attr_sub, text)

        def baseurl_sub(m):
            inner = m.group(2)
            if "movieplay" in inner:
                return m.group(0)
            return m.group(1) + seg_url(inner) + m.group(3)
        text = re.sub(r'(<BaseURL>)([^<]+)(</BaseURL>)', baseurl_sub, text)

        body = text.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/dash+xml")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _mode_seg(self, p, qs):
        u = (qs.get("u") or [""])[0]
        parts = urllib.parse.urlparse(u)
        if parts.scheme != "https" or parts.hostname not in MEDIA_HOSTS:
            return self._send_json(
                {"code": -1, "msg": "seg url not allowed"}, 400)
        item = {}
        hk = (qs.get("hk") or [""])[0].strip()
        tok = (qs.get("tok") or [""])[0].strip()
        if hk and tok:
            item = {"signHeaderKey": hk, "signCookie": tok}
        ref = (qs.get("ref") or [""])[0].strip() or "home"
        self._relay(u, _media_headers(ref, item))

    # ---------- entry ----------
    def do_GET(self):
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        mode = (qs.get("mode") or [""])[0].strip().lower()

        if mode == "seg":
            try:
                return self._mode_seg({}, qs)
            except Exception as e:
                return self._send_json(
                    {"code": -1, "msg": "Relay error: %s" % e}, 502)

        subject_id = (qs.get("subjectId") or [""])[0].strip()
        detail_path = (qs.get("detailPath") or [""])[0].strip()
        try:
            se = int((qs.get("se") or ["0"])[0])
            ep = int((qs.get("ep") or ["0"])[0])
        except ValueError:
            return self._send_json(
                {"code": -1, "msg": "se/ep must be numbers"}, 400)
        if not re.fullmatch(r"\d{5,25}", subject_id):
            return self._send_json(
                {"code": -1, "msg": "Missing/invalid subjectId"}, 400)
        if not re.fullmatch(r"[A-Za-z0-9\-]{3,120}", detail_path):
            return self._send_json(
                {"code": -1, "msg": "Missing/invalid detailPath"}, 400)
        p = {"subjectId": subject_id, "se": se, "ep": ep,
             "detailPath": detail_path,
             "res": (qs.get("res") or ["0"])[0]}

        try:
            if mode == "watch":
                return self._mode_watch(p)
            if mode == "dash":
                return self._mode_dash(p)
            # default: original JSON mode, behaviour unchanged
            data = _fetch_play(subject_id, se, ep, detail_path)
            return self._send_json(data)
        except urllib.error.HTTPError as e:
            return self._send_json(
                {"code": -1, "msg": "Upstream error: HTTP %d" % e.code}, 502)
        except Exception as e:
            return self._send_json(
                {"code": -1, "msg": "Upstream error: %s" % e}, 502)

    # keep the old name working (JSON mode used _send before)
    def _send(self, obj, status=200):
        return self._send_json(obj, status)

    def log_message(self, *args):
        pass
