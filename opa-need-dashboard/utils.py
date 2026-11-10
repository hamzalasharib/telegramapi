"""Pure helper functions: Firestore value decoding, secret redaction,
ownership matching and YouTube handling.

These functions have no network or Flask dependencies and are unit-tested
in tests/test_utils.py.
"""
import re

# ---------------------------------------------------------------------------
# Secret redaction
# ---------------------------------------------------------------------------
# Any field whose name contains one of these fragments is NEVER sent to the
# browser. This is a deny-list applied server-side, on every response.
SENSITIVE_FRAGMENTS = (
    "password", "passwd", "pwd", "token", "secret", "credential",
    "apikey", "api_key", "auth", "private", "session", "cookie",
    "otp", "pin_code", "cvv", "card_number",
)


def is_sensitive_field(name: str) -> bool:
    lowered = str(name).lower()
    return any(fragment in lowered for fragment in SENSITIVE_FRAGMENTS)


def sanitize(obj):
    """Recursively copy *obj* dropping every sensitive field."""
    if isinstance(obj, dict):
        return {
            key: sanitize(value)
            for key, value in obj.items()
            if not is_sensitive_field(key)
        }
    if isinstance(obj, list):
        return [sanitize(item) for item in obj]
    return obj


# ---------------------------------------------------------------------------
# Firestore REST value decoding
# ---------------------------------------------------------------------------
def decode_value(value):
    """Convert one Firestore REST typed value into a plain Python value."""
    if not isinstance(value, dict) or not value:
        return None
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        try:
            return int(value["integerValue"])
        except (TypeError, ValueError):
            return value["integerValue"]
    if "doubleValue" in value:
        return value["doubleValue"]
    if "booleanValue" in value:
        return bool(value["booleanValue"])
    if "timestampValue" in value:
        return value["timestampValue"]
    if "nullValue" in value:
        return None
    if "arrayValue" in value:
        return [decode_value(v) for v in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return {
            k: decode_value(v)
            for k, v in value["mapValue"].get("fields", {}).items()
        }
    if "referenceValue" in value:
        return value["referenceValue"]
    if "geoPointValue" in value:
        return value["geoPointValue"]
    return None


def decode_document(doc: dict) -> dict:
    """Turn a Firestore REST document into {'id': ..., <fields>}."""
    name = doc.get("name", "")
    doc_id = name.rsplit("/", 1)[-1] if name else ""
    out = {"id": doc_id}
    for key, raw in (doc.get("fields") or {}).items():
        out[key] = decode_value(raw)
    if doc.get("createTime"):
        out["_createTime"] = doc["createTime"]
    if doc.get("updateTime"):
        out["_updateTime"] = doc["updateTime"]
    return out


# ---------------------------------------------------------------------------
# Ownership matching  (the anti data-mixing core)
# ---------------------------------------------------------------------------
def _norm(value):
    return str(value).strip() if value is not None else ""


def link_belongs_to_user(link: dict, user: dict, user_key_field="category",
                         link_owner_field="email") -> bool:
    """Return True only on an exact ownership match. Never fuzzy.

    Rules, in order (first exact match wins):
      1. VERIFIED rule for this project: link[email] == user[category]
      2. link[userId|uid|ownerId|user_id] == user document id
      3. link[email|userEmail|ownerEmail] == user[email]  (real-email case)
      4. link[category] == user[category]
    A link matching none of these belongs to NOBODY and is treated as
    global/unassigned by the caller - it is never attached to a random user.
    """
    # Rule 1 - verified live mapping
    owner = _norm(link.get(link_owner_field))
    key = _norm(user.get(user_key_field))
    if owner and key and owner == key:
        return True
    # Rule 2 - document-id based ownership
    user_id = _norm(user.get("id"))
    for field in ("userId", "uid", "ownerId", "user_id", "owner_id"):
        if user_id and _norm(link.get(field)) == user_id:
            return True
    # Rule 3 - real e-mail ownership (excluding the already-checked field
    # when it carried a category code rather than an e-mail)
    user_email = _norm(user.get("email")).lower()
    if user_email and "@" in user_email:
        for field in ("userEmail", "ownerEmail", "email"):
            if _norm(link.get(field)).lower() == user_email:
                return True
    # Rule 4 - matching category fields on both sides
    link_cat = _norm(link.get("category"))
    if link_cat and key and link_cat == key:
        return True
    return False


def course_belongs_to_user(course: dict, user: dict) -> bool:
    """Courses in this project are a global catalog (createdBy = admin
    e-mails, no user field). Attach a course to a user ONLY on an exact
    match; everything else stays in the global catalog."""
    user_id = _norm(user.get("id"))
    user_email = _norm(user.get("email")).lower()
    for field in ("userId", "uid", "ownerId", "instructorId", "user_id"):
        if user_id and _norm(course.get(field)) == user_id:
            return True
    if user_email and "@" in user_email:
        for field in ("createdBy", "ownerEmail", "userEmail", "instructorEmail"):
            if _norm(course.get(field)).lower() == user_email:
                return True
    enrolled = course.get("enrolledUserIds") or course.get("participants") or []
    if isinstance(enrolled, list) and user_id and user_id in [_norm(x) for x in enrolled]:
        return True
    return False


# ---------------------------------------------------------------------------
# YouTube handling
# ---------------------------------------------------------------------------
_YT_PATTERNS = (
    re.compile(r"(?:youtube\.com/(?:watch\?[^#]*v=|shorts/|live/|embed/|v/))([A-Za-z0-9_-]{6,})"),
    re.compile(r"(?:youtu\.be/)([A-Za-z0-9_-]{6,})"),
    re.compile(r"(?:youtube-nocookie\.com/embed/)([A-Za-z0-9_-]{6,})"),
)


def youtube_video_id(url) -> str | None:
    """Extract a YouTube video id from watch / shorts / live / youtu.be
    URLs, or return None for non-YouTube URLs."""
    if not isinstance(url, str):
        return None
    for pattern in _YT_PATTERNS:
        match = pattern.search(url)
        if match:
            return match.group(1)
    return None


def youtube_embed_url(url) -> str | None:
    video_id = youtube_video_id(url)
    if not video_id:
        return None
    return f"https://www.youtube-nocookie.com/embed/{video_id}"


def youtube_thumbnail(url) -> str | None:
    video_id = youtube_video_id(url)
    if not video_id:
        return None
    return f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"


def enrich_link(link: dict) -> dict:
    """Add video metadata (id / embed / thumbnail) to a decoded link doc."""
    url = link.get("link") or link.get("url") or link.get("videoUrl") or ""
    video_id = youtube_video_id(url)
    return {
        **link,
        "url": url,
        "is_youtube": video_id is not None,
        "video_id": video_id,
        "embed_url": youtube_embed_url(url),
        "thumbnail": youtube_thumbnail(url),
    }


def dedupe_links(links: list) -> list:
    """Remove duplicate videos: same YouTube id (even with different
    tracking parameters) or the exact same URL / document id."""
    seen = set()
    out = []
    for link in links:
        key = link.get("video_id") or link.get("url") or link.get("id")
        if key in seen:
            continue
        seen.add(key)
        out.append(link)
    return out
