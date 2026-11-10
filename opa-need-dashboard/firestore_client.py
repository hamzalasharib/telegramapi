"""Server-side Firestore REST client.

The browser NEVER talks to Firestore directly. This module is the only
place that calls Google, which means credentials (when they exist later)
stay on the server and sensitive fields can be stripped before any
response leaves the backend.
"""
import time
import threading

import requests

from config import Config
from utils import decode_document


class FirestoreError(Exception):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


class FirestoreClient:
    def __init__(self, config=Config):
        self.cfg = config
        self._cache = {}
        self._cache_lock = threading.Lock()
        self._token = None
        self._token_expiry = 0

    # -- auth -------------------------------------------------------------
    def _access_token(self):
        """Return a bearer token when authorised access is configured,
        otherwise None (public-read mode)."""
        if self.cfg.ACCESS_TOKEN:
            return self.cfg.ACCESS_TOKEN
        if not self.cfg.SERVICE_ACCOUNT_FILE:
            return None
        now = time.time()
        if self._token and now < self._token_expiry - 60:
            return self._token
        try:
            from google.oauth2 import service_account
            from google.auth.transport.requests import Request as GoogleRequest

            creds = service_account.Credentials.from_service_account_file(
                self.cfg.SERVICE_ACCOUNT_FILE,
                scopes=["https://www.googleapis.com/auth/datastore"],
            )
            creds.refresh(GoogleRequest())
            self._token = creds.token
            self._token_expiry = creds.expiry.timestamp() if creds.expiry else now + 3000
            return self._token
        except Exception as exc:  # keep the site usable, but say why in logs
            raise FirestoreError(
                f"Service-account authentication failed: {exc}"
            ) from exc

    def _headers(self):
        headers = {"Accept": "application/json"}
        token = self._access_token()
        if token:
            headers["Authorization"] = f"Bearer {token}"
        return headers

    @property
    def access_mode(self):
        if self.cfg.ACCESS_TOKEN or self.cfg.SERVICE_ACCOUNT_FILE:
            return "authorised (token / service account)"
        return "public-read (no credentials configured)"

    # -- low level --------------------------------------------------------
    def _get(self, url, params=None):
        try:
            resp = requests.get(
                url, params=params, headers=self._headers(),
                timeout=self.cfg.REQUEST_TIMEOUT,
            )
        except requests.RequestException as exc:
            raise FirestoreError(f"Could not reach Firestore: {exc}") from exc
        if resp.status_code == 403:
            raise FirestoreError(
                "Firestore denied access (403 PERMISSION_DENIED). The "
                "project's security rules do not allow this read and no "
                "valid authorised access is configured. See SECURITY.md.",
                status=403,
            )
        if resp.status_code == 404:
            raise FirestoreError(
                "Collection or database not found (404). Check the project "
                "id, the (default) database and the collection name's case.",
                status=404,
            )
        if resp.status_code != 200:
            raise FirestoreError(
                f"Firestore returned HTTP {resp.status_code}.", status=resp.status_code
            )
        return resp.json()

    # -- collection reads ---------------------------------------------------
    def list_collection(self, collection, use_cache=True):
        """Fetch a whole collection (paginated), decoded to plain dicts."""
        now = time.time()
        with self._cache_lock:
            cached = self._cache.get(collection)
            if use_cache and cached and now - cached[0] < self.cfg.CACHE_TTL_SECONDS:
                return cached[1]

        docs = []
        page_token = None
        while len(docs) < self.cfg.MAX_DOCS_PER_COLLECTION:
            params = {"pageSize": self.cfg.PAGE_SIZE}
            if page_token:
                params["pageToken"] = page_token
            data = self._get(f"{self.cfg.FIRESTORE_BASE}/{collection}", params)
            for raw in data.get("documents", []):
                docs.append(decode_document(raw))
            page_token = data.get("nextPageToken")
            if not page_token:
                break

        with self._cache_lock:
            self._cache[collection] = (now, docs)
        return docs

    def get_document(self, collection, doc_id):
        data = self._get(f"{self.cfg.FIRESTORE_BASE}/{collection}/{doc_id}")
        if not data:
            return None
        return decode_document(data)

    def ping(self):
        """Cheap access check: read a single document from Users."""
        try:
            self._get(
                f"{self.cfg.FIRESTORE_BASE}/{self.cfg.COLLECTION_USERS}",
                {"pageSize": 1},
            )
            return {"ok": True, "mode": self.access_mode}
        except FirestoreError as exc:
            return {"ok": False, "mode": self.access_mode, "error": str(exc),
                    "status": exc.status}
