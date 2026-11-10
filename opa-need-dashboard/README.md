# OPA Need — Web Dashboard

A complete, free-tier friendly Flask website that shows the **same data as
the existing Android app**, read server-side from the app's own Firestore
database. The Android app is not changed in any way.

- **Project:** `opa-need` · **Database:** `(default)`
- **Collections:** `Users`, `Links`, `courses`

---

## 1. What the investigation found (verified live, 2026-11-11)

The database was checked through the official Firestore REST API before
any code was written. Facts, not guesses:

| Collection | Documents | Fields found |
|---|---|---|
| `Users` | 17 | `email`, `category`, `created`, `password` |
| `Links` | 256 | `email`, `type` (always `video`), `link`, `created` |
| `courses` | 3 | `name`, `description`, `module`, `provider`, `trainingType`, `attachmentUrls`, `imageUrl`, `createdBy`, `points`, … |

Important discoveries:

1. **Access:** the database currently answers **without any login**
   (public read is enabled by the project's own rules). That is the only
   reason a website can read it today without the Firebase Console.
   See `SECURITY.md` — this also means the data, including passwords,
   is readable by anyone who knows the project id. Tell the original
   developer.
2. **Users' `email` field is a username code** (e.g. `fia76`, `pak654`),
   not a real e-mail address.
3. **Ownership rule (proven, not assumed):** `Links.email` holds a single
   letter, and that letter equals the owner's `Users.category`.
   Every one of the 16 user categories matches a set of links
   (e.g. `fia76` → category `W` → 29 videos). One letter, `O`, has videos
   but no user today — those are shown as **Unassigned**, never mixed
   into another user's list.
4. **Courses are a global catalog**, created by admin e-mails
   (`createdBy`), with no field pointing at a normal user. They are
   therefore shown in their own catalog section. If a course ever gets a
   real owner field (`userId`, `instructorId`, …), the backend attaches
   it to that user automatically.
5. **Passwords exist in `Users` in plain text.** They are stripped
   server-side and **never** sent to the browser (see `utils.sanitize`).

## 2. Features

- Search users by username (or category letter), exact → prefix →
  substring ranking, paging for large user bases.
- User page: profile, **only that user's videos**, embedded responsive
  YouTube player (watch / Shorts / live / youtu.be), duplicates removed.
- Course catalog with attachment links; per-user courses when owned.
- Premium dark UI, fully responsive, loading states, error toasts.
- Security: server-side Firestore access only, secret-field redaction,
  input validation, per-IP rate limiting (90 req/min), strict security
  headers / CSP, no credentials in the frontend.
- 45-second server cache → fast pages and fewer Firestore reads.

## 3. Run it locally (5 minutes)

```bash
cd opa-need-dashboard
python3 -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env        # defaults already work, editing is optional
python app.py
```

Open http://127.0.0.1:5000

Production-style run:

```bash
gunicorn app:app --bind 0.0.0.0:5000 --workers 2
```

## 4. API

| Endpoint | Purpose |
|---|---|
| `GET /api/health` | Is Firestore reachable, and in which access mode? |
| `GET /api/stats` | Totals: users, links, unique videos, courses, categories |
| `GET /api/users?q=&offset=&limit=` | Search users (no sensitive fields) |
| `GET /api/users/<id>` | One user + their videos + their courses |
| `GET /api/courses` | Global course catalog |
| `GET /api/links/unassigned` | Videos whose owner code matches no user |

## 5. Files

```
app.py               Flask backend + API routes
config.py            Settings / environment variables / ownership mapping
firestore_client.py  Server-side Firestore REST client (+ optional auth)
security.py          Rate limiting + security headers
utils.py             Decoding, redaction, ownership matching, YouTube
templates/index.html Page
static/css/style.css Premium dark responsive UI
static/js/app.js     Frontend logic (no external libraries)
tests/test_utils.py  Unit tests for the critical logic
DEPLOYMENT.md        Free hosting, step by step
SECURITY.md          Security model + what the owner should fix
TROUBLESHOOTING.md   Common problems and fixes
```

## 6. Deploy for free

See **DEPLOYMENT.md** (Render free tier recommended — free subdomain,
no card, no paid database).

## 7. Redeem codes (sell weekly / monthly access) — v2

The dashboard is locked behind a redeem code:

- **Buyer flow:** visitor opens the site → redeem page → enters a code →
  dashboard unlocks for that plan (**weekly = 7 days, monthly = 30
  days**, counted from the moment of first redemption). The same code
  can be re-entered on a new device before it expires; after expiry it
  is dead. Access is carried by a signed session cookie — never share
  your own browser session.
- **Seller flow (you):**
  1. In the hosting panel's **ENV** tab add `ADMIN_PASSWORD` with a
     password you choose, then restart the app.
  2. Open **`/admin`**, log in, pick Weekly or Monthly, choose how many
     codes, optionally write the buyer's name as a note, and Generate.
  3. New codes are shown once — copy them and sell them. The admin page
     lists every code with its status (unused / active / expired) and
     lets you delete a code (deleting an active code ends that buyer's
     access on their next visit).
- **Storage:** codes live in a local SQLite file `data/redeem.db`
  (created automatically; standard library only, no paid database).
  Firestore is never written to. Back up `data/redeem.db` if you move
  hosting — it is your sales record.
- **Emergency open access:** set ENV `ACCESS_GATE_DISABLED=1` and
  restart to open the dashboard without codes (e.g. while setting up).
  Set it back to `0` before selling.
- Session signing key: ENV `SECRET_KEY` if set, otherwise generated
  once into `data/.secret_key` so sessions survive restarts.
