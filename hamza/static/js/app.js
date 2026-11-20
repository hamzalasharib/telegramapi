"use strict";
/* OPA Need dashboard - vanilla JS, no external dependencies. */

const $ = (id) => document.getElementById(id);
const els = {
  input: $("searchInput"), loading: $("loading"), toast: $("toast"),
  usersSection: $("usersSection"), usersGrid: $("usersGrid"),
  usersEmpty: $("usersEmpty"), usersTitle: $("usersTitle"), usersCount: $("usersCount"),
  detail: $("detailSection"), profile: $("profileCard"),
  playerWrap: $("playerWrap"), player: $("playerFrame"), nowPlaying: $("nowPlaying"),
  videosGrid: $("videosGrid"), videosEmpty: $("videosEmpty"), videoCount: $("videoCount"),
  userCoursesHead: $("userCoursesHead"), userCoursesGrid: $("userCoursesGrid"),
  userCoursesCount: $("userCoursesCount"),
  coursesSection: $("coursesSection"), coursesGrid: $("coursesGrid"),
  coursesEmpty: $("coursesEmpty"), coursesCount: $("coursesCount"),
  unassignedSection: $("unassignedSection"), unassignedGrid: $("unassignedGrid"),
  unassignedCount: $("unassignedCount"),
  healthText: $("healthText"),
};

function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}
function fmtDate(value) {
  if (!value) return "—";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? esc(value) : d.toLocaleDateString(undefined,
    { year: "numeric", month: "short", day: "numeric" });
}
function showLoading(on) { els.loading.hidden = !on; }
function toast(message, ok = false) {
  els.toast.textContent = message;
  els.toast.className = "toast" + (ok ? " ok" : "");
  els.toast.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { els.toast.hidden = true; }, 6000);
}
async function api(path) {
  const res = await fetch(path, { headers: { Accept: "application/json" } });
  let data = {};
  try { data = await res.json(); } catch (_) { /* non-JSON error page */ }
  if (res.status === 401 || data.locked) {
    window.location.href = "/redeem";
    throw new Error("Access locked — redirecting to redeem page…");
  }
  if (!res.ok || data.ok === false) {
    throw new Error(data.error || `Request failed (HTTP ${res.status})`);
  }
  return data;
}
function showSection(name) {
  els.usersSection.hidden = name !== "users";
  els.detail.hidden = name !== "detail";
  els.coursesSection.hidden = name !== "courses";
  els.unassignedSection.hidden = name !== "unassigned";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

/* ---------------- health + stats ---------------- */
async function loadHealth() {
  try {
    const data = await api("/api/health");
    document.querySelector("#healthBadge .dot").className = "dot dot-ok";
    els.healthText.textContent = "Database connected";
  } catch (e) {
    document.querySelector("#healthBadge .dot").className = "dot dot-bad";
    els.healthText.textContent = "Database not reachable";
    toast(e.message);
  }
}
async function loadStats() {
  try {
    const { stats } = await api("/api/stats");
    document.querySelectorAll("[data-stat]").forEach((node) => {
      const key = node.getAttribute("data-stat");
      if (stats[key] !== undefined) node.textContent = stats[key];
    });
  } catch (_) { /* health badge already explains it */ }
}

/* ---------------- users ---------------- */
function userCard(user) {
  const initial = esc((user.username || "?").charAt(0).toUpperCase());
  return `
  <button class="card user-card" data-user="${esc(user.id)}">
    <div class="avatar">${initial}</div>
    <h4>${esc(user.username)}</h4>
    <p class="meta">
      <span class="tag">Category ${esc(user.category ?? "—")}</span>
      🎬 ${esc(user.video_count ?? 0)} videos<br>
      Joined: ${fmtDate(user.created)}
    </p>
  </button>`;
}

let searchTimer = null;
async function loadUsers(query = "") {
  showSection("users");
  showLoading(true);
  els.usersEmpty.hidden = true;
  try {
    const data = await api(`/api/users?limit=100&q=${encodeURIComponent(query)}`);
    els.usersTitle.textContent = query ? `Results for “${query}”` : "Users";
    els.usersCount.textContent = `${data.total} user${data.total === 1 ? "" : "s"}`;
    els.usersGrid.innerHTML = data.users.map(userCard).join("");
    els.usersEmpty.hidden = data.users.length > 0;
    els.usersGrid.querySelectorAll("[data-user]").forEach((btn) => {
      btn.addEventListener("click", () => loadUser(btn.getAttribute("data-user")));
    });
  } catch (e) {
    els.usersGrid.innerHTML = "";
    toast(e.message);
  } finally { showLoading(false); }
}

/* ---------------- user detail ---------------- */
function videoCard(video) {
  const thumb = video.thumbnail
    ? `<div class="play-badge"><img loading="lazy" src="${esc(video.thumbnail)}" alt="Video thumbnail"></div>`
    : "";
  return `
  <button class="card video-card" data-embed="${esc(video.embed_url || "")}" data-url="${esc(video.url || "")}">
    ${thumb}
    <div class="v-body">
      <p>▶ Play video</p>
      <p>${esc(video.url || "")}</p>
      <p>${fmtDate(video.created)}</p>
    </div>
  </button>`;
}
function playVideo(embedUrl, pageUrl) {
  if (!embedUrl) { toast("This link is not a playable YouTube video."); return; }
  els.player.src = `${embedUrl}?rel=0`;
  els.nowPlaying.textContent = pageUrl || "";
  els.playerWrap.hidden = false;
  els.playerWrap.scrollIntoView({ behavior: "smooth", block: "center" });
}

function courseCard(course) {
  const attachments = (course.attachments || []).map((a, i) =>
    `<a class="attach" href="${esc(a)}" target="_blank" rel="noopener">📎 Attachment ${i + 1}</a>`).join("");
  const image = course.image_url
    ? `<img loading="lazy" src="${esc(course.image_url)}" alt="" style="width:100%;border-radius:10px;margin-bottom:10px">` : "";
  const rows = [
    ["Module", course.module], ["Provider", course.provider],
    ["Type", course.training_type], ["Location", course.location],
    ["Points", course.points], ["Duration", course.duration],
    ["Starts", course.start_date ? fmtDate(course.start_date) : null],
    ["Status", course.status || (course.is_active ? "Active" : null)],
  ].filter(([, v]) => v !== null && v !== undefined && v !== "")
   .map(([k, v]) => `${esc(k)}: <b>${esc(v)}</b>`).join(" · ");
  return `
  <article class="card course-card">
    ${image}
    <h4>${esc(course.name)}</h4>
    <p class="meta">${esc(course.description || "")}</p>
    <p class="meta" style="margin-top:8px">${rows}</p>
    ${attachments}
  </article>`;
}

async function loadUser(userId) {
  showLoading(true);
  try {
    const data = await api(`/api/users/${encodeURIComponent(userId)}`);
    const u = data.user;
    els.profile.innerHTML = `
      <div class="avatar">${esc((u.username || "?").charAt(0).toUpperCase())}</div>
      <div>
        <h3>${esc(u.username)}</h3>
        <p class="meta">
          <span class="tag">Category ${esc(u.category ?? "—")}</span>
          🎬 ${esc(data.video_count)} videos · Joined: ${fmtDate(u.created)}<br>
          <span style="font-size:12px">User ID: ${esc(u.id)}</span>
        </p>
      </div>`;
    els.videoCount.textContent = `${data.video_count} videos`;
    els.videosGrid.innerHTML = data.videos.map(videoCard).join("");
    els.videosEmpty.hidden = data.videos.length > 0;
    els.videosGrid.querySelectorAll("[data-embed]").forEach((btn) => {
      btn.addEventListener("click", () =>
        playVideo(btn.getAttribute("data-embed"), btn.getAttribute("data-url")));
    });

    const mine = data.courses || [];
    els.userCoursesHead.hidden = mine.length === 0;
    els.userCoursesCount.textContent = mine.length ? `${mine.length}` : "";
    els.userCoursesGrid.innerHTML = mine.map(courseCard).join("");

    els.player.src = "";
    els.playerWrap.hidden = true;
    showSection("detail");
    if (data.videos.length) {
      playVideo(data.videos[0].embed_url, data.videos[0].url);
    }
  } catch (e) { toast(e.message); }
  finally { showLoading(false); }
}

/* ---------------- courses + unassigned ---------------- */
async function loadCourses() {
  showLoading(true);
  try {
    const data = await api("/api/courses");
    els.coursesCount.textContent = `${data.courses.length} courses`;
    els.coursesGrid.innerHTML = data.courses.map(courseCard).join("");
    els.coursesEmpty.hidden = data.courses.length > 0;
    showSection("courses");
  } catch (e) { toast(e.message); }
  finally { showLoading(false); }
}
async function loadUnassigned() {
  showLoading(true);
  try {
    const data = await api("/api/links/unassigned");
    els.unassignedCount.textContent = `${data.count} videos`;
    els.unassignedGrid.innerHTML = data.videos.map(videoCard).join("");
    els.unassignedGrid.querySelectorAll("[data-embed]").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (!btn.getAttribute("data-embed")) { toast("Not a playable YouTube video."); return; }
        window.open(btn.getAttribute("data-url"), "_blank", "noopener");
      });
    });
    showSection("unassigned");
  } catch (e) { toast(e.message); }
  finally { showLoading(false); }
}

/* ---------------- events ---------------- */
$("searchBtn").addEventListener("click", () => loadUsers(els.input.value.trim()));
els.input.addEventListener("keydown", (e) => {
  if (e.key === "Enter") loadUsers(els.input.value.trim());
});
els.input.addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => loadUsers(els.input.value.trim()), 350);
});
$("showAllBtn").addEventListener("click", () => { els.input.value = ""; loadUsers(""); });
$("showCoursesBtn").addEventListener("click", loadCourses);
$("showUnassignedBtn").addEventListener("click", loadUnassigned);
$("backBtn").addEventListener("click", () => { els.player.src = ""; loadUsers(els.input.value.trim()); });
document.querySelectorAll("[data-back]").forEach((b) =>
  b.addEventListener("click", () => loadUsers(els.input.value.trim())));

/* ---------------- init ---------------- */
loadHealth();
loadStats();
loadUsers("");
