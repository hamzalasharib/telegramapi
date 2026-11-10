# Security

## The honest starting point

During the investigation (2026-11-11) the Firestore database of project
`opa-need` answered REST reads **with no authentication at all**, for
all three collections. That can only happen if the project's Firestore
Security Rules allow public read, for example:

```
allow read: if true;
```

Consequences you must understand:

1. **Anyone** who knows the project id (`opa-need` — it is printed in
   every API URL) can read the whole database with a browser.
2. The `Users` collection stores `password` in **plain text**, so those
   passwords are effectively public today. This is not caused by this
   website — it is the existing state of the database — and this website
   cannot fix it. Only the person with Firebase Console access can.
3. Do **not** "fix" it by copying this dashboard's approach elsewhere or
   by sharing raw collection dumps.

## What this dashboard does to stay safe

- **Server-side only access.** The browser never talks to Firestore and
  never receives any credential. All reads happen in `firestore_client.py`.
- **Secret redaction.** Every response passes through `utils.sanitize`,
  which drops any field whose name contains `password`, `token`,
  `secret`, `credential`, `apikey`, `auth`, `session`, `otp`, …
  Verify yourself: open `/api/users` — there is no `password` in it.
- **Exact ownership matching.** A video is attached to a user only when
  `Links.email == Users.category` (the verified rule) or an explicit id /
  e-mail owner field matches exactly. Unmatched items are shown
  separately as *Unassigned*. Nothing is ever guessed or randomised.
- **Validation & rate limiting.** Search text is length-capped, user ids
  must match `^[A-Za-z0-9_-]{1,128}$`, paging values are clamped, and
  each IP is limited (default 90 API requests/minute → HTTP 429).
- **Headers.** CSP (only `youtube-nocookie.com` may be framed),
  `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`.
- **No Admin SDK, no service-account key in the code or repo.**
  `.gitignore` blocks `*service-account*.json` and `.env`.

## If the owner tightens the rules (recommended)

Ask the original developer to:

1. Change the rules so reads require authentication, e.g.
   `allow read: if request.auth != null;` (exact rules depend on how
   the Android app signs users in — the developer knows).
2. **Stop storing plain-text passwords** in `Users`. Passwords belong in
   Firebase Authentication, never in a Firestore document.
3. Give this website **limited, read-only** authorised access, in one of
   these ways (no console access for you is needed):
   - **Best:** a service-account JSON whose only role is
     *Cloud Datastore Viewer* (`roles/datastore.viewer`). Set
     `GOOGLE_SERVICE_ACCOUNT_FILE=/path/to/key.json` in the server's
     environment. Keep that file out of Git and out of chat messages.
   - **For a quick test only:** a short-lived OAuth access token in
     `FIRESTORE_ACCESS_TOKEN` (it expires in about an hour).

Until that happens, this dashboard works in public-read mode, and its
`/api/health` endpoint honestly reports that mode.

## What NOT to do

- Do not make the database writable from the web (`allow write: if true`)
  to "fix" a problem — this site never writes anything.
- Do not paste a service-account key into frontend code, GitHub, or a
  chat. If a key ever leaks, the owner must delete it in the console.
- Do not embed the Firestore API key / config from the APK into a public
  web page to read data client-side; that would expose every field —
  including passwords — to every visitor's browser.
