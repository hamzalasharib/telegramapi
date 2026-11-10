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
