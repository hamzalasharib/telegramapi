"""Vercel entry point: exposes the Flask app as a serverless function."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app as _flask_app  # noqa: E402


def _debug_app(environ, start_response):
    """Temporary diagnostic: /__dbg?k=... dumps WSGI environ (no cookies)."""
    safe = {k: v for k, v in sorted(environ.items())
            if isinstance(v, str) and "cookie" not in k.lower()
            and "auth" not in k.lower()}
    body = json.dumps(safe, indent=1).encode()
    start_response("200 OK", [("Content-Type", "application/json"),
                              ("Content-Length", str(len(body)))])
    return [body]


def app(environ, start_response):
    if "dbg=hamza" in (environ.get("QUERY_STRING") or ""):
        return _debug_app(environ, start_response)
    return _flask_app(environ, start_response)
