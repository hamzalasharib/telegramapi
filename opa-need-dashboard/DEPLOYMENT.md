# Deployment — free hosting, step by step

You need: this project folder, a free account on the hosting site.
You do **not** need: a credit card, a new database, or Firebase Console
access (for the current public-read state of the project).

---

## Option A — Render (recommended, free subdomain)

1. Put this folder in a free GitHub account:
   - Go to github.com → sign up (free) → **New repository** → name it
     `opa-need-dashboard` → upload all files of this folder
     (drag & drop works). **Do not upload a `.env` file or any
     service-account JSON.**
2. Go to render.com → sign up with GitHub (free, no card).
3. Click **New + → Web Service** → choose your repository.
4. Fill in:
   - **Runtime:** Python 3
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --timeout 60`
   - **Instance Type:** Free
5. In **Environment Variables**, add only:
   - `SECRET_KEY` = any long random text you invent
   - (nothing else is required — the defaults point at project `opa-need`)
6. Click **Create Web Service**. After 2–5 minutes Render gives you a
   free address like `https://opa-need-dashboard.onrender.com`.
7. Open it. The badge at the top should say **Database connected**.

Notes: the free instance sleeps after ~15 idle minutes; the first visit
after that takes ~30–60 seconds to wake. That is normal on the free tier.

## Option B — PythonAnywhere (free, no GitHub needed)

1. Sign up at pythonanywhere.com (free Beginner account).
2. Open a **Bash console** and run:
   ```bash
   pip install --user flask requests gunicorn python-dotenv google-auth
   ```
   Then upload the project files via the **Files** tab into
   `/home/<yourname>/opa-need-dashboard`.
3. Go to the **Web** tab → **Add a new web app** → **Flask** → Python 3.
4. Edit the WSGI file it creates so it contains:
   ```python
   import sys
   sys.path.insert(0, "/home/<yourname>/opa-need-dashboard")
   from app import app as application
   ```
5. Click **Reload**. Your free address is
   `https://<yourname>.pythonanywhere.com`.

Note: free PythonAnywhere accounts can only reach whitelisted external
sites; `firestore.googleapis.com` may need to be on their allow-list —
if the health badge says "not reachable", use Option A instead.

## Option C — Railway / Fly.io (free trials / allowances change often)

Both can run the same `Procfile` (`gunicorn app:app ...`) with no code
changes. Check their current free terms before choosing; Render above is
the option verified to need no card.

## After deployment — 2-minute checklist

- [ ] Home page loads, top badge = **Database connected**
- [ ] Stats row shows 17 users / 256 links / 3 courses (numbers grow
      with the app — they just have to be non-zero)
- [ ] Search `fia76` → 1 user → open it → videos play (expect ~29)
- [ ] Search a wrong name → friendly "No user found", no crash
- [ ] Open `/api/users` in the browser: confirm **no `password` field**
      appears anywhere in the output
- [ ] On your phone: layout fits, player is responsive

## Updating later

Change files → push to GitHub → Render redeploys automatically.
The Android app and the database are never touched by this website
(it only reads).
