"""Random Hadith API for hadith.html.
The old source (random-hadith-generator.vercel.app) is gone (deployment
deleted). New source: fawazahmed0/hadith-api English editions served from
the jsDelivr CDN. This function fetches an edition once, caches it in
memory, and returns one random hadith in the exact shape the page uses:
{data: {book, bookName, chapterName, header, hadith_english, refno}}"""
import json, random, urllib.request, urllib.parse
from http.server import BaseHTTPRequestHandler

EDITIONS = {
    "bukhari":  ("eng-bukhari",  "Bukhari"),
    "muslim":   ("eng-muslim",   "Muslim"),
    "tirmidhi": ("eng-tirmidhi", "Tirmidhi"),
    "ibnmajah": ("eng-ibnmajah", "Ibn Majah"),
    "abudawud": ("eng-abudawud", "Abu Dawud"),
}
CDN = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/%s.min.json"
_cache = {}

def load(col):
    if col in _cache:
        return _cache[col]
    edition, _ = EDITIONS[col]
    req = urllib.request.Request(CDN % edition, headers={"User-Agent": "HamzaEditz/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode("utf-8", "ignore"))
    data["_pool"] = [h for h in data.get("hadiths", []) if (h.get("text") or "").strip()]
    _cache[col] = data
    return data

class handler(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        col = (q.get("c", ["bukhari"])[0] or "bukhari").lower()
        if col not in EDITIONS:
            return self._send(400, {"error": "Unknown collection"})
        try:
            data = load(col)
            meta = data.get("metadata", {})
            sections = meta.get("sections", {})
            h = random.choice(data["_pool"])
            ref = h.get("reference", {}) or {}
            book_no = str(ref.get("book", ""))
            chapter = sections.get(book_no, "") if isinstance(sections, dict) else ""
            book_title = meta.get("name", EDITIONS[col][1])
            number = h.get("hadithnumber", ref.get("hadith", ""))
            return self._send(200, {"data": {
                "book": EDITIONS[col][1],
                "bookName": book_title,
                "chapterName": chapter,
                "header": f"Hadith No. {number}" if number else "",
                "hadith_english": (h.get("text") or "").strip(),
                "refno": f"{book_title} {number}".strip(),
            }})
        except Exception as e:
            return self._send(502, {"error": f"Hadith source unreachable: {str(e)[:80]}"})

    def log_message(self, *args):
        pass
