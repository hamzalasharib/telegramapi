"""Redeem-code system (weekly / monthly access) for the dashboard.

Storage: a local SQLite file (data/redeem.db inside the project) using
only Python's standard library - no extra packages, no paid database,
and the Android app's Firestore is NEVER written to.

How it works:
  * The owner (admin) generates codes: plan "weekly" = 7 days,
    plan "monthly" = 30 days.
  * A buyer enters a code once. The code activates at that moment and
    its expiry is fixed: activated_at + plan days.
  * Re-entering the SAME code before expiry simply restores access on
    a new browser/device (cookies cleared, phone changed). After
    expiry the code is dead forever.
  * Access itself is carried by Flask's signed session cookie, so no
    code value is ever stored in the browser.
"""
import os
import secrets
import sqlite3
import string
import threading
from datetime import datetime, timedelta, timezone

PLANS = {
    "weekly": {"days": 7, "label": "Weekly (7 days)"},
    "monthly": {"days": 30, "label": "Monthly (30 days)"},
}

_ALPHABET = string.ascii_uppercase + string.digits


def _now():
    return datetime.now(timezone.utc)


def _iso(dt):
    return dt.astimezone(timezone.utc).isoformat() if dt else None


def _parse(text):
    if not text:
        return None
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def generate_code_value(prefix="OPA"):
    """e.g. OPA-7K2QX-9M4TD - random, no look-alike grouping issues."""
    def chunk(n):
        return "".join(secrets.choice(_ALPHABET) for _ in range(n))
    return f"{prefix}-{chunk(5)}-{chunk(5)}"


def normalize_code(raw: str) -> str:
    return "".join(str(raw or "").split()).upper()


class RedeemStore:
    def __init__(self, db_path):
        self.db_path = db_path
        self._lock = threading.Lock()
        folder = os.path.dirname(db_path)
        if folder:
            os.makedirs(folder, exist_ok=True)
        self._init()

    def _conn(self):
        conn = sqlite3.connect(self.db_path, timeout=10)
        conn.row_factory = sqlite3.Row
        return conn

    def _init(self):
        with self._lock, self._conn() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS codes (
                    code         TEXT PRIMARY KEY,
                    plan         TEXT NOT NULL,
                    days         INTEGER NOT NULL,
                    created_at   TEXT NOT NULL,
                    activated_at TEXT,
                    expires_at   TEXT,
                    note         TEXT DEFAULT ''
                )
            """)
            # v5: per-device access records (device info, profile, block)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS accesses (
                    token         TEXT PRIMARY KEY,
                    code          TEXT NOT NULL,
                    device        TEXT DEFAULT '',
                    profile_name  TEXT DEFAULT '',
                    profile_phone TEXT DEFAULT '',
                    created_at    TEXT NOT NULL,
                    last_seen     TEXT NOT NULL,
                    blocked       INTEGER NOT NULL DEFAULT 0
                )
            """)
            # v5: admin -> user messages (notification / warning / update / info)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS messages (
                    id         INTEGER PRIMARY KEY AUTOINCREMENT,
                    target     TEXT NOT NULL DEFAULT 'all',
                    kind       TEXT NOT NULL DEFAULT 'notification',
                    title      TEXT DEFAULT '',
                    body       TEXT DEFAULT '',
                    url        TEXT DEFAULT '',
                    created_at TEXT NOT NULL
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS message_reads (
                    message_id INTEGER NOT NULL,
                    token      TEXT NOT NULL,
                    PRIMARY KEY (message_id, token)
                )
            """)

    # -- admin --------------------------------------------------------------
    def create_codes(self, plan: str, quantity: int, note: str = "") -> list:
        if plan not in PLANS:
            raise ValueError(f"Unknown plan: {plan}")
        quantity = max(1, min(200, int(quantity)))
        days = PLANS[plan]["days"]
        created = []
        with self._lock, self._conn() as conn:
            while len(created) < quantity:
                value = generate_code_value()
                try:
                    conn.execute(
                        "INSERT INTO codes (code, plan, days, created_at, note)"
                        " VALUES (?, ?, ?, ?, ?)",
                        (value, plan, days, _iso(_now()), note[:120]),
                    )
                    created.append(value)
                except sqlite3.IntegrityError:
                    continue  # astronomically unlikely collision; retry
        return created

    def list_codes(self, limit=300) -> list:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM codes ORDER BY created_at DESC LIMIT ?", (limit,)
            ).fetchall()
        return [self._public(dict(row)) for row in rows]

    def delete_code(self, code: str) -> bool:
        with self._lock, self._conn() as conn:
            cur = conn.execute("DELETE FROM codes WHERE code = ?",
                               (normalize_code(code),))
            return cur.rowcount > 0

    def stats(self) -> dict:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT plan, activated_at, expires_at FROM codes").fetchall()
        total = len(rows)
        active = unused = expired = 0
        now = _now()
        for row in rows:
            exp = _parse(row["expires_at"])
            if not row["activated_at"]:
                unused += 1
            elif exp and exp > now:
                active += 1
            else:
                expired += 1
        return {"total": total, "unused": unused, "active": active,
                "expired": expired}

    # -- buyer --------------------------------------------------------------
    def _public(self, row: dict) -> dict:
        now = _now()
        exp = _parse(row.get("expires_at"))
        if not row.get("activated_at"):
            status = "unused"
        elif exp and exp > now:
            status = "active"
        else:
            status = "expired"
        return {
            "code": row["code"],
            "plan": row["plan"],
            "days": row["days"],
            "created_at": row.get("created_at"),
            "activated_at": row.get("activated_at"),
            "expires_at": row.get("expires_at"),
            "status": status,
            "note": row.get("note") or "",
        }

    def redeem(self, raw_code: str) -> dict:
        """Activate (or re-enter) a code.

        Returns {"ok": True, "plan":..., "expires_at":..., "days_left":...}
        or {"ok": False, "error": "..."}."""
        code = normalize_code(raw_code)
        if not code:
            return {"ok": False, "error": "Please enter your redeem code."}
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT * FROM codes WHERE code = ?",
                               (code,)).fetchone()
            if row is None:
                return {"ok": False, "error": "Invalid code. Please check and try again."}
            row = dict(row)
            now = _now()
            if not row["activated_at"]:
                expires = now + timedelta(days=int(row["days"]))
                conn.execute(
                    "UPDATE codes SET activated_at = ?, expires_at = ? WHERE code = ?",
                    (_iso(now), _iso(expires), code),
                )
                row["activated_at"], row["expires_at"] = _iso(now), _iso(expires)
            exp = _parse(row["expires_at"])
            if not exp or exp <= now:
                return {"ok": False,
                        "error": "This code has expired. Please buy a new code."}
            days_left = (exp - now).total_seconds() / 86400
            return {"ok": True, "code": code, "plan": row["plan"],
                    "expires_at": row["expires_at"],
                    "days_left": round(days_left, 1)}

    def code_status(self, raw_code: str) -> dict | None:
        code = normalize_code(raw_code)
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT * FROM codes WHERE code = ?",
                               (code,)).fetchone()
        return self._public(dict(row)) if row else None

    # -- v5: access records (device / profile / block) ----------------------
    def create_access(self, code: str, device: str = "") -> str:
        """Create (or reuse) the access record for a code+device pair.

        Reuse matters: if the same phone re-enters its code after
        clearing app data, it must get its profile, block state and
        message history back instead of starting as a stranger."""
        code = normalize_code(code)
        device = (device or "")[:160]
        now = _iso(_now())
        with self._lock, self._conn() as conn:
            if device:
                row = conn.execute(
                    "SELECT token FROM accesses WHERE code = ? AND device = ?"
                    " ORDER BY created_at DESC LIMIT 1",
                    (code, device)).fetchone()
                if row:
                    conn.execute(
                        "UPDATE accesses SET last_seen = ? WHERE token = ?",
                        (now, row["token"]))
                    return row["token"]
            token = secrets.token_urlsafe(24)
            conn.execute(
                "INSERT INTO accesses (token, code, device, created_at, last_seen)"
                " VALUES (?, ?, ?, ?, ?)",
                (token, code, device, now, now))
            return token

    def _access_public(self, row: dict) -> dict:
        status = self.code_status(row["code"]) or {}
        return {
            "token": row["token"],
            "code": row["code"],
            "plan": status.get("plan"),
            "code_status": status.get("status"),
            "expires_at": status.get("expires_at"),
            "device": row.get("device") or "",
            "profile_name": row.get("profile_name") or "",
            "profile_phone": row.get("profile_phone") or "",
            "created_at": row.get("created_at"),
            "last_seen": row.get("last_seen"),
            "blocked": bool(row.get("blocked")),
        }

    def get_access(self, token: str) -> dict | None:
        if not token:
            return None
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT * FROM accesses WHERE token = ?",
                               (token,)).fetchone()
        return self._access_public(dict(row)) if row else None

    def touch_access(self, token: str):
        with self._lock, self._conn() as conn:
            conn.execute("UPDATE accesses SET last_seen = ? WHERE token = ?",
                         (_iso(_now()), token))

    def set_profile(self, token: str, name: str, phone: str = "") -> bool:
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                "UPDATE accesses SET profile_name = ?, profile_phone = ?"
                " WHERE token = ?",
                (name[:60], (phone or "")[:24], token))
            return cur.rowcount > 0

    def set_blocked(self, token: str = "", code: str = "",
                    blocked: bool = True) -> int:
        """Block/unblock one access (by token) or every access of a code."""
        with self._lock, self._conn() as conn:
            if token:
                cur = conn.execute(
                    "UPDATE accesses SET blocked = ? WHERE token = ?",
                    (1 if blocked else 0, token))
            elif code:
                cur = conn.execute(
                    "UPDATE accesses SET blocked = ? WHERE code = ?",
                    (1 if blocked else 0, normalize_code(code)))
            else:
                return 0
            return cur.rowcount

    def list_accesses(self, limit=300) -> list:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM accesses ORDER BY created_at DESC LIMIT ?",
                (limit,)).fetchall()
        return [self._access_public(dict(row)) for row in rows]

    # -- v5: admin -> user messages -----------------------------------------
    MESSAGE_KINDS = ("notification", "warning", "update", "info")

    def create_message(self, target: str, kind: str, title: str,
                       body: str, url: str = "") -> int:
        if kind not in self.MESSAGE_KINDS:
            raise ValueError(f"Unknown message kind: {kind}")
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                "INSERT INTO messages (target, kind, title, body, url, created_at)"
                " VALUES (?, ?, ?, ?, ?, ?)",
                ((target or "all")[:80], kind, (title or "")[:120],
                 (body or "")[:1000], (url or "")[:300], _iso(_now())))
            return cur.lastrowid

    def unread_messages(self, token: str, code: str) -> list:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM messages WHERE (target = 'all' OR target = ?"
                " OR target = ?) AND id NOT IN"
                " (SELECT message_id FROM message_reads WHERE token = ?)"
                " ORDER BY id ASC",
                (token, normalize_code(code), token)).fetchall()
        return [dict(row) for row in rows]

    def mark_read(self, token: str, message_ids) -> int:
        done = 0
        with self._lock, self._conn() as conn:
            for mid in message_ids or []:
                try:
                    conn.execute(
                        "INSERT OR IGNORE INTO message_reads (message_id, token)"
                        " VALUES (?, ?)", (int(mid), token))
                    done += 1
                except (TypeError, ValueError):
                    continue
        return done
