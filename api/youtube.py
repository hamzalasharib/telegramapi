"""YouTube formats API — port of the user's snapyt.app worker.

GET /api/youtube?url=<youtube link>
  -> {success: true, formats: [{fmt, label, size, kind, download}]}
  -> {success: false, error: "..."} on failure

Runs the same three steps as the Cloudflare Worker the user supplied:
ask snapyt.app for a nonce, submit the video URL, then parse the format
options out of the preview page it returns. snapyt is a third-party site
and drops connections fairly often, so each run retries the whole chain
a few times and the preview page read tolerates a cut-off response.
"""
import http.client
import json
import re
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

AJAX_URL = "https://www.snapyt.app/wp-admin/admin-ajax.php"
SITE = "https://www.snapyt.app/"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
HDR = {
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "X-Requested-With": "XMLHttpRequest",
    "Referer": SITE,
    "User-Agent": UA,
}


def _post(data, timeout=15):
    req = urllib.request.Request(
        AJAX_URL, data=urllib.parse.urlencode(data).encode(), headers=HDR
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))


def _get_text(url, timeout=22):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode("utf-8", "ignore")
    except http.client.IncompleteRead as e:
        # snapyt sometimes closes the preview page stream early; the
        # format options sit near the top, so the partial page is enough.
        return e.partial.decode("utf-8", "ignore")


def _attr(tag, name):
    m = re.search(r'data-' + name + r'="([^"]*)"', tag)
    return m.group(1) if m else ""


def _parse_formats(html):
    formats = []
    for tag in re.findall(r"<option\b[^>]*>", html):
        v = re.search(r'value="(\d+)"', tag)
        if not v:
            continue
        force = _attr(tag, "force")
        formats.append(
            {
                "fmt": int(v.group(1)),
                "label": _attr(tag, "label").replace("\xa0", " ").strip()
                or ("Format " + v.group(1)),
                "size": _attr(tag, "size"),
                "kind": _attr(tag, "kind") or "video+audio",
                "download": (
                    force.replace("&#038;", "&").replace("&amp;", "&") or None
                ),
            }
        )
    seen = set()
    out = []
    for f in formats:
        if f["fmt"] in seen:
            continue
        seen.add(f["fmt"])
        out.append(f)
    return out


def fetch_formats(video_url):
    last = None
    for _ in range(3):
        try:
            j = _post({"action": "vd_fresh_nonce"}, timeout=12)
            nonce = j["data"]["nonce"]
            j2 = _post(
                {
                    "action": "process_video_url",
                    "video_url": video_url,
                    "security": nonce,
                },
                timeout=18,
            )
            if not j2.get("success") or not (j2.get("data") or {}).get("redirect"):
                raise RuntimeError("Submit failed: " + json.dumps(j2)[:200])
            html = _get_text(j2["data"]["redirect"])
            formats = _parse_formats(html)
            if not formats:
                raise RuntimeError("No formats found on the preview page")
            return formats
        except Exception as e:  # connection drops are routine on snapyt
            last = e
            time.sleep(1.2)
    raise RuntimeError(str(last) if last else "snapyt did not respond")


class handler(BaseHTTPRequestHandler):
    def _send(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send({}, 204)

    def do_GET(self):
        qs = parse_qs(urlparse(self.path).query)
        video_url = (qs.get("url", [""])[0] or "").strip()
        if not video_url:
            return self._send(
                {"success": False, "error": "Missing ?url="}, 400
            )
        if "youtu" not in video_url:
            return self._send(
                {"success": False, "error": "Please paste a YouTube link."}, 400
            )
        try:
            formats = fetch_formats(video_url)
            self._send({"success": True, "formats": formats})
        except Exception as e:
            self._send(
                {
                    "success": False,
                    "error": "Could not fetch formats. The source site is busy — please try again.",
                    "detail": str(e)[:200],
                },
                502,
            )
