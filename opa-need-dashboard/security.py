"""Small, dependency-free security helpers: per-IP rate limiting and
security response headers."""
import time
import threading
from collections import defaultdict, deque

from flask import request, jsonify


class RateLimiter:
    """Fixed-window per-IP limiter (in-memory; fine for free-tier,
    single-instance hosting)."""

    def __init__(self, limit_per_minute=90):
        self.limit = limit_per_minute
        self._hits = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.time()
        window_start = now - 60
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] < window_start:
                hits.popleft()
            if len(hits) >= self.limit:
                return False
            hits.append(now)
            return True


def register_security(app, limiter: RateLimiter):
    @app.before_request
    def _rate_limit():
        if request.path.startswith("/api/"):
            client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "?")
            client_ip = client_ip.split(",")[0].strip()
            if not limiter.allow(client_ip):
                return jsonify({
                    "ok": False,
                    "error": "Too many requests. Please wait a minute and try again.",
                }), 429
        return None

    @app.after_request
    def _headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        # YouTube embeds need frame-src youtube; everything else stays tight.
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "img-src 'self' https://i.ytimg.com data:; "
            "frame-src https://www.youtube-nocookie.com https://www.youtube.com; "
            "style-src 'self'; script-src 'self'; "
            "connect-src 'self'; base-uri 'self'; form-action 'self'"
        )
        return response
