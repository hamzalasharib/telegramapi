"""Unit tests for the pure helpers. Run:  python -m pytest tests/ -q
(No network and no Flask needed for these.)"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from utils import (  # noqa: E402
    sanitize, is_sensitive_field, decode_document,
    link_belongs_to_user, course_belongs_to_user,
    youtube_video_id, youtube_embed_url, enrich_link, dedupe_links,
)


# --- redaction ---------------------------------------------------------------
def test_password_and_token_are_always_removed():
    dirty = {"email": "fia76", "password": "secret1",
             "nested": {"accessToken": "abc", "name": "ok"}}
    clean = sanitize(dirty)
    assert clean == {"email": "fia76", "nested": {"name": "ok"}}
    assert is_sensitive_field("Password")
    assert is_sensitive_field("refresh_token")
    assert not is_sensitive_field("category")


# --- Firestore decoding --------------------------------------------------------
def test_decode_document():
    doc = {
        "name": "projects/x/databases/(default)/documents/Users/ABC123",
        "fields": {
            "email": {"stringValue": "fia76"},
            "category": {"stringValue": "W"},
            "points": {"integerValue": "5"},
            "active": {"booleanValue": True},
            "tags": {"arrayValue": {"values": [{"stringValue": "a"}]}},
            "image": {"nullValue": None},
        },
        "createTime": "2026-01-01T00:00:00Z",
    }
    out = decode_document(doc)
    assert out["id"] == "ABC123"
    assert out["email"] == "fia76" and out["points"] == 5
    assert out["tags"] == ["a"] and out["image"] is None


# --- ownership: the verified live rule ---------------------------------------
def test_verified_category_rule():
    user = {"id": "u1", "email": "fia76", "category": "W"}
    assert link_belongs_to_user({"email": "W"}, user) is True
    assert link_belongs_to_user({"email": "N"}, user) is False  # other user's
    assert link_belongs_to_user({"email": "O"}, user) is False  # unassigned
    assert link_belongs_to_user({}, user) is False              # no owner field


def test_id_and_real_email_rules():
    user = {"id": "doc99", "email": "real@gmail.com", "category": "A"}
    assert link_belongs_to_user({"userId": "doc99"}, user) is True
    assert link_belongs_to_user({"userEmail": "real@gmail.com"}, user) is True
    assert link_belongs_to_user({"userId": "someone-else"}, user) is False


def test_course_ownership_is_strict():
    user = {"id": "u1", "email": "fia76", "category": "W"}
    global_course = {"createdBy": "admin@gmail.com", "name": "jnj"}
    assert course_belongs_to_user(global_course, user) is False
    assert course_belongs_to_user({"instructorId": "u1"}, user) is True


# --- YouTube -------------------------------------------------------------------
def test_youtube_id_forms():
    assert youtube_video_id("https://www.youtube.com/watch?v=Z50bFhZge7U&t=9") == "Z50bFhZge7U"
    assert youtube_video_id("https://youtu.be/Z50bFhZge7U?si=xyz") == "Z50bFhZge7U"
    assert youtube_video_id("https://www.youtube.com/shorts/Z50bFhZge7U") == "Z50bFhZge7U"
    assert youtube_video_id("https://www.youtube.com/live/Z50bFhZge7U?si=xyz") == "Z50bFhZge7U"
    assert youtube_video_id("https://example.com/video.mp4") is None
    assert youtube_video_id("") is None
    assert youtube_embed_url("https://youtu.be/Z50bFhZge7U") == \
        "https://www.youtube-nocookie.com/embed/Z50bFhZge7U"


def test_dedupe_removes_same_video_with_different_tracking_params():
    a = enrich_link({"id": "1", "link": "https://youtu.be/Z50bFhZge7U?si=aaa"})
    b = enrich_link({"id": "2", "link": "https://www.youtube.com/watch?v=Z50bFhZge7U"})
    c = enrich_link({"id": "3", "link": "https://youtu.be/PqJwqOZIKas"})
    out = dedupe_links([a, b, c])
    assert [x["id"] for x in out] == ["1", "3"]
