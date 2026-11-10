# Troubleshooting + Testing

## Quick test checklist (after any install/deploy)

```bash
# 1. Unit tests for the critical logic (ownership, redaction, YouTube)
pip install pytest
python -m pytest tests/ -q          # expect: all passed

# 2. Start the server
python app.py

# 3. In a second terminal:
curl http://127.0.0.1:5000/api/health     # {"ok": true, ...}
curl http://127.0.0.1:5000/api/stats      # users 17, links 256, courses 3 (or more, as data grows)
curl "http://127.0.0.1:5000/api/users?q=fia76"   # 1 user, NO password field
```

Then in the browser:

- Search `fia76` → open the user → **about 29 videos**, first video plays
  automatically in the embedded player.
- Search `cur723` → about **38 videos** (different user, different list —
  if two users show identical lists, something is wrong; report it).
- Click **Course catalog** → 3 courses, shown as global.
- Click **Unassigned videos** → videos with owner code `O`.
- Resize / open on a phone → layout adapts, player stays 16:9.

## Problems

### Top badge says "Database not reachable" / 403 PERMISSION_DENIED
The project's rules no longer allow public read and no authorised
access is configured. This is a permissions fact, not a code bug.
→ Ask the developer for read-only authorised access (see SECURITY.md)
and set `GOOGLE_SERVICE_ACCOUNT_FILE` (or, for a test,
`FIRESTORE_ACCESS_TOKEN`). Do not ask anyone to "just open the rules
again" without understanding the password exposure described there.

### 404 on a collection
Collection names are case-sensitive: `Users`, `Links`, `courses`
(exactly this case). If the developer renames one, set
`COLLECTION_USERS` / `COLLECTION_LINKS` / `COLLECTION_COURSES`
environment variables to the new names.

### A user shows 0 videos but the app shows some
1. Check the user's `category` in `/api/users?q=<name>` and compare with
   the `owner_code` values in the app — the link owner code must equal
   the category letter exactly.
2. If the developer changed the data model (for example links now carry
   `userId`), update `USER_LINK_KEY_FIELD` / `LINK_OWNER_FIELD` in the
   environment, or extend `utils.link_belongs_to_user` — the id/e-mail
   rules are already built in.
3. Wait up to 45 seconds — the server caches collections for that long.

### Videos appear twice / a video won't play
- Duplicates are removed by YouTube video id, so the same video shared
  as `youtu.be/...?si=...` and `youtube.com/watch?v=...` counts once.
- "Won't play": the uploader may have disabled embedding for that video
  on YouTube itself. Test by opening the same link on youtube.com —
  if embedding is disabled there is no website-side fix.

### Page loads slowly the first time
Free hosting sleeps when idle (Render: ~30–60 s wake-up) and the first
request fills the 45 s cache. Later visits are fast.

### 429 "Too many requests"
You (or many visitors behind one IP) crossed the per-minute limit.
Wait a minute, or raise `RATE_LIMIT_PER_MINUTE` in the environment.

### Numbers differ from the app
This website only reads; it never writes. If a number differs, hard
refresh after 45 s (cache) and compare the same moment in the app —
data may simply have changed in between. Document counts verified on
2026-11-11: Users 17, Links 256, courses 3.

### Local run: "ModuleNotFoundError: flask"
You are outside the virtual environment. Run
`source venv/bin/activate` (Windows: `venv\Scripts\activate`), then
`pip install -r requirements.txt` again.
