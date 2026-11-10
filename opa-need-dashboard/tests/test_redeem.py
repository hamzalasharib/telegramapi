"""Tests for the redeem-code store. Run: python -m pytest tests/ -q"""
import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from redeem import RedeemStore, normalize_code  # noqa: E402


def make_store(tmp_path):
    return RedeemStore(str(tmp_path / "redeem.db"))


def test_generate_and_redeem_weekly(tmp_path):
    store = make_store(tmp_path)
    codes = store.create_codes("weekly", 2)
    assert len(codes) == 2 and codes[0].startswith("OPA-")
    result = store.redeem(codes[0])
    assert result["ok"] and result["plan"] == "weekly"
    assert 6.9 < result["days_left"] <= 7.0
    # Second code stays unused
    assert store.code_status(codes[1])["status"] == "unused"
    stats = store.stats()
    assert stats == {"total": 2, "unused": 1, "active": 1, "expired": 0}


def test_monthly_plan_is_30_days(tmp_path):
    store = make_store(tmp_path)
    code = store.create_codes("monthly", 1)[0]
    result = store.redeem(code)
    assert result["ok"] and 29.9 < result["days_left"] <= 30.0


def test_wrong_code_and_code_reuse_before_expiry(tmp_path):
    store = make_store(tmp_path)
    assert store.redeem("OPA-XXXXX-YYYYY")["ok"] is False
    code = store.create_codes("weekly", 1)[0]
    first = store.redeem(code)
    again = store.redeem(code.lower().replace("-", " - "))  # messy typing
    assert first["ok"] and again["ok"]
    assert again["expires_at"] == first["expires_at"]  # expiry never extends


def test_expired_code_is_dead(tmp_path):
    store = make_store(tmp_path)
    code = store.create_codes("weekly", 1)[0]
    past = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
    long_ago = (datetime.now(timezone.utc) - timedelta(days=8)).isoformat()
    import sqlite3
    with sqlite3.connect(store.db_path) as conn:
        conn.execute("UPDATE codes SET activated_at=?, expires_at=? WHERE code=?",
                     (long_ago, past, code))
    assert store.redeem(code)["ok"] is False
    assert store.code_status(code)["status"] == "expired"


def test_normalize():
    assert normalize_code(" opa-ab cd-12 ") == "OPA-ABCD-12"
