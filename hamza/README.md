# OPA Need Dashboard — Vercel build (folder: hamza)

Same dashboard as the panel version (v5: redeem codes, user profiles,
devices, block, admin messages), prepared for Vercel.

## Vercel project settings
- **Root Directory:** `hamza`
- **Framework Preset:** Other (Python is detected from `api/index.py` +
  `requirements.txt`)
- **Environment Variables (required):**
  - `ADMIN_PASSWORD` — the admin password for /admin and the admin app.
    Without it the admin side stays disabled.
  - `SECRET_KEY` — optional; a long random string for session cookies.

## Important limitation
Vercel has no permanent disk. The SQLite store (`/tmp/redeem.db`) resets
whenever the serverless instance recycles, so redeem codes / users /
messages created here are NOT permanent. Keep the panel hosting
(sirpaid.silenthost.site) as the selling system of record; treat this
deployment as a mirror/demo unless an external database is added.
