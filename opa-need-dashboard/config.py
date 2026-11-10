"""Configuration for the OPA Need dashboard.

All values can be overridden with environment variables (see .env.example).
No secrets are hard-coded here.
"""
import os


class Config:
    # --- Firestore -------------------------------------------------------
    PROJECT_ID = os.environ.get("FIRESTORE_PROJECT_ID", "opa-need")
    DATABASE_ID = os.environ.get("FIRESTORE_DATABASE_ID", "(default)")
    FIRESTORE_BASE = (
        "https://firestore.googleapis.com/v1/projects/"
        f"{PROJECT_ID}/databases/{DATABASE_ID}/documents"
    )

    # Optional authorised access. Leave empty while the project's rules
    # allow public read (the current state, verified 2026-11-11).
    # If the owner later tightens the rules, provide ONE of these:
    #   FIRESTORE_ACCESS_TOKEN          - a short-lived OAuth2 access token
    #   GOOGLE_SERVICE_ACCOUNT_FILE     - path to a service-account JSON
    #                                     granted ONLY roles/datastore.viewer
    ACCESS_TOKEN = os.environ.get("FIRESTORE_ACCESS_TOKEN", "").strip()
    SERVICE_ACCOUNT_FILE = os.environ.get("GOOGLE_SERVICE_ACCOUNT_FILE", "").strip()

    # Collections (exact names / case as they exist in Firestore)
    COLLECTION_USERS = os.environ.get("COLLECTION_USERS", "Users")
    COLLECTION_LINKS = os.environ.get("COLLECTION_LINKS", "Links")
    COLLECTION_COURSES = os.environ.get("COLLECTION_COURSES", "courses")

    # --- Ownership mapping (VERIFIED against the live database) ----------
    # Users:   { email: "fia76", category: "W", created: <ts>, password: *** }
    # Links:   { email: "W",     type: "video", link: <youtube>, created: <ts> }
    # => A link belongs to a user when Links.email == Users.category.
    # The matcher in utils.py ALSO checks the conventional fields below so
    # the dashboard keeps working if the developer adds them later, but the
    # verified category rule above is tried first and is what matches today.
    USER_LINK_KEY_FIELD = os.environ.get("USER_LINK_KEY_FIELD", "category")
    LINK_OWNER_FIELD = os.environ.get("LINK_OWNER_FIELD", "email")

    # --- Redeem codes / access gate --------------------------------------
    # Set ADMIN_PASSWORD in the hosting panel's ENV tab. It protects the
    # /admin page where sellable weekly/monthly codes are generated.
    # If it is empty, the admin page stays disabled (the dashboard and
    # redeeming still work) - see README "Redeem codes".
    ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "").strip()
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    REDEEM_DB_PATH = os.environ.get(
        "REDEEM_DB_PATH", os.path.join(BASE_DIR, "data", "redeem.db"))
    SECRET_FILE = os.path.join(BASE_DIR, "data", ".secret_key")
    # When "1", the dashboard is open without a code (emergency switch
    # for the owner; keep "0" while selling access).
    ACCESS_GATE_DISABLED = os.environ.get("ACCESS_GATE_DISABLED", "0") == "1"

    # --- Server ----------------------------------------------------------
    SECRET_KEY = os.environ.get("SECRET_KEY", "").strip()
    HOST = os.environ.get("HOST", "0.0.0.0")
    PORT = int(os.environ.get("PORT", "5000"))
    DEBUG = os.environ.get("FLASK_DEBUG", "0") == "1"

    # --- Limits / performance -------------------------------------------
    CACHE_TTL_SECONDS = int(os.environ.get("CACHE_TTL_SECONDS", "45"))
    MAX_DOCS_PER_COLLECTION = int(os.environ.get("MAX_DOCS", "5000"))
    PAGE_SIZE = 300
    RATE_LIMIT_PER_MINUTE = int(os.environ.get("RATE_LIMIT_PER_MINUTE", "90"))
    REQUEST_TIMEOUT = int(os.environ.get("REQUEST_TIMEOUT", "20"))


def get_secret_key() -> str:
    """Session-signing key: ENV SECRET_KEY if set, otherwise a random key
    generated once and kept in data/.secret_key so buyer sessions survive
    server restarts on the free panel."""
    if Config.SECRET_KEY:
        return Config.SECRET_KEY
    try:
        if os.path.exists(Config.SECRET_FILE):
            with open(Config.SECRET_FILE, "r", encoding="utf-8") as fh:
                saved = fh.read().strip()
            if saved:
                return saved
        import secrets as _secrets
        value = _secrets.token_hex(32)
        os.makedirs(os.path.dirname(Config.SECRET_FILE), exist_ok=True)
        with open(Config.SECRET_FILE, "w", encoding="utf-8") as fh:
            fh.write(value)
        return value
    except OSError:
        # Storage not writable: sessions still work, they just reset
        # whenever the process restarts.
        return "temporary-key-sessions-reset-on-restart"
