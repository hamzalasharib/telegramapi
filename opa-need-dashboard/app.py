"""OPA Need - Web Dashboard

Flask backend that mirrors the Android app's Firestore data on the web.

Data flow:
    Browser  ->  this Flask server  ->  Firestore REST API (server-side)

The browser never calls Firestore directly, so:
  * sensitive fields (password / token / ...) are stripped server-side,
  * ownership matching happens server-side with exact rules,
  * credentials, if ever configured, never reach the frontend.

Verified live structure (2026-11-11, project opa-need):
  Users   (17 docs) : email (username code), category (1 letter), created,
                      password  -> NEVER returned
  Links   (256 docs): email (= the owner's category letter), type="video",
                      link (YouTube URL), created
  courses (3 docs)  : global catalog, createdBy = admin e-mail,
                      attachmentUrls (currently empty), imageUrl, ...
"""
import hmac
import re
from datetime import datetime, timedelta, timezone

from flask import (Flask, jsonify, redirect, render_template, request,
                   session, url_for, abort)

from config import Config, get_secret_key
from firestore_client import FirestoreClient, FirestoreError
from redeem import PLANS, RedeemStore
from security import RateLimiter, register_security
from utils import (
    sanitize, enrich_link, dedupe_links,
    link_belongs_to_user, course_belongs_to_user,
)

app = Flask(__name__)
app.secret_key = get_secret_key()
app.permanent_session_lifetime = timedelta(days=35)

db = FirestoreClient(Config)
store = RedeemStore(Config.REDEEM_DB_PATH)
register_security(app, RateLimiter(Config.RATE_LIMIT_PER_MINUTE))


# ---------------------------------------------------------------------------
# Redeem-code access gate
# ---------------------------------------------------------------------------
_PUBLIC_PREFIXES = ("/static/", "/redeem", "/admin", "/api/health", "/favicon")


def current_access():
    """Return {'plan':..., 'expires_at':..., 'days_left':...} when the
    visitor holds a valid, unexpired redeem session, else None."""
    if Config.ACCESS_GATE_DISABLED:
        return {"plan": "owner", "expires_at": None, "days_left": None}
    code = session.get("access_code")
    expires_at = session.get("expires_at")
    if not code or not expires_at:
        return None
    try:
        exp = datetime.fromisoformat(expires_at)
    except ValueError:
        return None
    now = datetime.now(timezone.utc)
    if exp <= now:
        session.pop("access_code", None)
        return None
    status = store.code_status(code)
    if not status or status["status"] != "active":
        session.pop("access_code", None)
        return None
    return {"plan": session.get("plan") or status["plan"],
            "expires_at": expires_at,
            "days_left": round((exp - now).total_seconds() / 86400, 1)}


@app.before_request
def _access_gate():
    path = request.path
    if any(path == p or path.startswith(p) for p in _PUBLIC_PREFIXES):
        return None
    if current_access() is not None:
        return None
    if path.startswith("/api/"):
        return jsonify({"ok": False, "locked": True,
                        "error": "Access locked. Please redeem a code first."}), 401
    return redirect(url_for("redeem_page"))


def is_admin() -> bool:
    return bool(Config.ADMIN_PASSWORD) and bool(session.get("is_admin"))

USER_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
MAX_QUERY_LEN = 100


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def public_user(user: dict, link_count=None) -> dict:
    """The ONLY shape of user data that may leave this server."""
    clean = sanitize(user)
    out = {
        "id": clean.get("id"),
        # In this project the 'email' field holds the username code
        # (e.g. "fia76"); it is shown as the username.
        "username": clean.get("email") or clean.get("username") or clean.get("name") or "Unknown",
        "email": clean.get("email"),
        "category": clean.get("category"),
        "created": clean.get("created") or clean.get("_createTime"),
    }
    # Keep any other harmless profile fields the developer may add later.
    for key, value in clean.items():
        if key not in out and not key.startswith("_") and key != "id":
            out[key] = value
    if link_count is not None:
        out["video_count"] = link_count
    return out


def public_course(course: dict) -> dict:
    clean = sanitize(course)
    attachments = clean.get("attachmentUrls") or clean.get("attachments") or []
    if isinstance(attachments, str):
        attachments = [attachments]
    return {
        "id": clean.get("id"),
        "name": clean.get("name") or clean.get("title") or "Untitled course",
        "description": clean.get("description") or "",
        "module": clean.get("module"),
        "provider": clean.get("provider"),
        "location": clean.get("location"),
        "training_type": clean.get("trainingType"),
        "points": clean.get("points"),
        "duration": clean.get("duration"),
        "validity_months": clean.get("validityMonths"),
        "max_participants": clean.get("maxParticipants"),
        "participant_count": clean.get("participantCount"),
        "is_active": clean.get("isActive"),
        "status": clean.get("status"),
        "start_date": clean.get("startDate"),
        "end_date": clean.get("endDate"),
        "created_at": clean.get("createdAt") or clean.get("_createTime"),
        "created_by": clean.get("createdBy"),
        "image_url": clean.get("imageUrl"),
        "prerequisites": clean.get("prerequisites") or [],
        "attachments": [a for a in attachments if a],
    }


def load_all():
    users = db.list_collection(Config.COLLECTION_USERS)
    links = [enrich_link(doc) for doc in db.list_collection(Config.COLLECTION_LINKS)]
    courses = db.list_collection(Config.COLLECTION_COURSES)
    return users, links, courses


def user_links(user, links):
    mine = [
        link for link in links
        if link_belongs_to_user(link, user, Config.USER_LINK_KEY_FIELD,
                                Config.LINK_OWNER_FIELD)
    ]
    mine.sort(key=lambda l: str(l.get("created") or ""), reverse=True)
    return dedupe_links(mine)


def error_response(exc, status=502):
    code = getattr(exc, "status", None) or status
    return jsonify({"ok": False, "error": str(exc)}), code


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    access = current_access() or {}
    return render_template("index.html", project_id=Config.PROJECT_ID,
                           plan=access.get("plan"),
                           days_left=access.get("days_left"))


# ---------------------------------------------------------------------------
# Redeem + admin pages
# ---------------------------------------------------------------------------
@app.route("/redeem", methods=["GET", "POST"])
def redeem_page():
    if current_access() is not None:
        return redirect(url_for("index"))
    error = None
    if request.method == "POST":
        result = store.redeem(request.form.get("code", ""))
        if result["ok"]:
            session.permanent = True
            session["access_code"] = result["code"]
            session["plan"] = result["plan"]
            session["expires_at"] = result["expires_at"]
            return redirect(url_for("index"))
        error = result["error"]
    return render_template("redeem.html", error=error, plans=PLANS)


@app.route("/access/logout")
def access_logout():
    session.pop("access_code", None)
    session.pop("plan", None)
    session.pop("expires_at", None)
    return redirect(url_for("redeem_page"))


@app.route("/admin", methods=["GET"])
def admin_page():
    generated = session.pop("last_generated", [])
    return render_template(
        "admin.html",
        admin_enabled=bool(Config.ADMIN_PASSWORD),
        is_admin=is_admin(),
        codes=store.list_codes() if is_admin() else [],
        stats=store.stats() if is_admin() else {},
        plans=PLANS,
        generated=generated,
        error=request.args.get("error"),
    )


@app.route("/admin/login", methods=["POST"])
def admin_login():
    password = request.form.get("password", "")
    if Config.ADMIN_PASSWORD and hmac.compare_digest(password, Config.ADMIN_PASSWORD):
        session["is_admin"] = True
        return redirect(url_for("admin_page"))
    return redirect(url_for("admin_page", error="Wrong admin password."))


@app.route("/admin/generate", methods=["POST"])
def admin_generate():
    if not is_admin():
        abort(403)
    plan = request.form.get("plan", "monthly")
    try:
        quantity = int(request.form.get("quantity", 1))
    except ValueError:
        quantity = 1
    note = request.form.get("note", "")
    try:
        session["last_generated"] = store.create_codes(plan, quantity, note)
    except ValueError:
        return redirect(url_for("admin_page", error="Unknown plan."))
    return redirect(url_for("admin_page"))


@app.route("/admin/delete", methods=["POST"])
def admin_delete():
    if not is_admin():
        abort(403)
    store.delete_code(request.form.get("code", ""))
    return redirect(url_for("admin_page"))


@app.route("/admin/logout", methods=["POST"])
def admin_logout():
    session.pop("is_admin", None)
    return redirect(url_for("admin_page"))


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------
@app.route("/api/health")
def health():
    result = db.ping()
    return jsonify({"ok": result["ok"], "firestore": result,
                    "project_id": Config.PROJECT_ID})


@app.route("/api/stats")
def stats():
    try:
        users, links, courses = load_all()
    except FirestoreError as exc:
        return error_response(exc)
    categories = {str(u.get("category")) for u in users if u.get("category")}
    assigned = 0
    for link in links:
        if any(link_belongs_to_user(link, u, Config.USER_LINK_KEY_FIELD,
                                    Config.LINK_OWNER_FIELD) for u in users):
            assigned += 1
    return jsonify({
        "ok": True,
        "stats": {
            "users": len(users),
            "links": len(links),
            "videos_unique": len(dedupe_links(links)),
            "courses": len(courses),
            "categories": len(categories),
            "links_assigned": assigned,
            "links_unassigned": len(links) - assigned,
        },
    })


@app.route("/api/users")
def search_users():
    """Search users by username ('email' field) - case-insensitive,
    exact matches first, then prefix, then substring. Supports paging
    with ?offset= & ?limit= so large user bases stay fast."""
    query = (request.args.get("q") or "").strip()
    if len(query) > MAX_QUERY_LEN:
        return jsonify({"ok": False, "error": "Search text is too long."}), 400
    try:
        offset = max(0, int(request.args.get("offset", 0)))
        limit = min(100, max(1, int(request.args.get("limit", 50))))
    except ValueError:
        return jsonify({"ok": False, "error": "Invalid paging values."}), 400

    try:
        users, links, _ = load_all()
    except FirestoreError as exc:
        return error_response(exc)

    counts = {}
    for user in users:
        counts[user["id"]] = len(user_links(user, links))

    if query:
        q = query.lower()

        def rank(user):
            name = str(user.get("email") or user.get("username") or "").lower()
            category = str(user.get("category") or "").lower()
            if name == q:
                return 0
            if name.startswith(q):
                return 1
            if q in name:
                return 2
            if category == q:
                return 3
            return None

        matched = [(rank(u), u) for u in users]
        matched = [(r, u) for r, u in matched if r is not None]
        matched.sort(key=lambda pair: (pair[0], str(pair[1].get("email") or "")))
        ordered = [u for _, u in matched]
    else:
        ordered = sorted(users, key=lambda u: str(u.get("email") or ""))

    total = len(ordered)
    page = ordered[offset:offset + limit]
    return jsonify({
        "ok": True,
        "total": total,
        "offset": offset,
        "limit": limit,
        "users": [public_user(u, counts.get(u["id"], 0)) for u in page],
    })


@app.route("/api/users/<user_id>")
def user_detail(user_id):
    if not USER_ID_RE.match(user_id):
        abort(400)
    try:
        users, links, courses = load_all()
    except FirestoreError as exc:
        return error_response(exc)

    user = next((u for u in users if u.get("id") == user_id), None)
    if user is None:
        return jsonify({"ok": False, "error": "User not found."}), 404

    mine_links = user_links(user, links)
    my_courses = [public_course(c) for c in courses if course_belongs_to_user(c, user)]
    global_courses = [public_course(c) for c in courses
                      if not any(course_belongs_to_user(c, u) for u in users)]

    videos = [{
        "id": link.get("id"),
        "url": link.get("url"),
        "embed_url": link.get("embed_url"),
        "thumbnail": link.get("thumbnail"),
        "video_id": link.get("video_id"),
        "type": link.get("type") or "video",
        "created": link.get("created"),
    } for link in mine_links]

    return jsonify({
        "ok": True,
        "user": public_user(user, len(videos)),
        "videos": videos,
        "video_count": len(videos),
        "courses": my_courses,            # only courses truly owned by this user
        "global_courses": global_courses,  # catalog courses, clearly separated
    })


@app.route("/api/courses")
def all_courses():
    """The global course catalog (in this project courses are not owned
    by normal users - see README)."""
    try:
        _, _, courses = load_all()
    except FirestoreError as exc:
        return error_response(exc)
    return jsonify({"ok": True, "courses": [public_course(c) for c in courses]})


@app.route("/api/links/unassigned")
def unassigned_links():
    """Links whose owner code matches no user (today: category 'O').
    Shown separately - never mixed into any user's list."""
    try:
        users, links, _ = load_all()
    except FirestoreError as exc:
        return error_response(exc)
    orphans = [
        link for link in links
        if not any(link_belongs_to_user(link, u, Config.USER_LINK_KEY_FIELD,
                                        Config.LINK_OWNER_FIELD) for u in users)
    ]
    orphans = dedupe_links(orphans)
    return jsonify({
        "ok": True,
        "count": len(orphans),
        "videos": [{
            "id": l.get("id"), "url": l.get("url"),
            "embed_url": l.get("embed_url"), "thumbnail": l.get("thumbnail"),
            "video_id": l.get("video_id"),
            "owner_code": l.get(Config.LINK_OWNER_FIELD),
            "created": l.get("created"),
        } for l in orphans],
    })


@app.errorhandler(400)
def bad_request(_):
    return jsonify({"ok": False, "error": "Bad request."}), 400


@app.errorhandler(404)
def not_found(_):
    if request.path.startswith("/api/"):
        return jsonify({"ok": False, "error": "Not found."}), 404
    return render_template("index.html", project_id=Config.PROJECT_ID), 404


if __name__ == "__main__":
    app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
