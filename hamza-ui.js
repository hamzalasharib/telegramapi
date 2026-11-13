/* HamzaEditz UI v6 — dark portfolio theme (companion to hamza-ui.css v6).
   The brand header lives ONLY on the tools page (home.html); tool pages
   get no injected header/hero/footer. Full-screen app pages get one tiny
   Home link. This script adds the theme fonts and the starfield
   background to content pages. */
(() => {
  const root = document.documentElement;
  root.dataset.theme = 'dark';

  const APP_PAGES = ['welcome.html', 'tvchannels.html', 'alltv.html', 'sulu', 'sulu.html', 'spotify'];

  function manifestLink() {
    if (!document.querySelector('link[rel="manifest"]')) {
      const l = document.createElement('link');
      l.rel = 'manifest'; l.href = 'manifest.webmanifest';
      document.head.appendChild(l);
    }
  }
  function fonts() {
    if (document.querySelector('link[data-hz-fonts]')) return;
    const p1 = document.createElement('link'); p1.rel = 'preconnect'; p1.href = 'https://fonts.googleapis.com';
    const p2 = document.createElement('link'); p2.rel = 'preconnect'; p2.href = 'https://fonts.gstatic.com'; p2.crossOrigin = '';
    const f = document.createElement('link');
    f.rel = 'stylesheet'; f.setAttribute('data-hz-fonts', '');
    f.href = 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500;700&family=Space+Grotesk:wght@500;600;700&display=swap';
    document.head.appendChild(p1); document.head.appendChild(p2); document.head.appendChild(f);
  }
  function starfield() {
    if (document.getElementById('hz-stars')) return;
    const cv = document.createElement('canvas'); cv.id = 'hz-stars';
    const g1 = document.createElement('div'); g1.className = 'hz-glow hz-glow-a';
    const g2 = document.createElement('div'); g2.className = 'hz-glow hz-glow-b';
    document.body.prepend(g2); document.body.prepend(g1); document.body.prepend(cv);
    const cx = cv.getContext('2d');
    let W, H, stars = [], shot = null;
    function size() {
      W = cv.width = innerWidth; H = cv.height = innerHeight;
      stars = [];
      const n = Math.min(150, Math.floor(W * H / 10000));
      for (let i = 0; i < n; i++) stars.push({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.3 + .3, p: Math.random() * 6.28, s: .4 + Math.random() * 1.2 });
    }
    size(); addEventListener('resize', size);
    (function tick(t) {
      cx.clearRect(0, 0, W, H);
      for (const s of stars) {
        cx.globalAlpha = .3 + .65 * Math.abs(Math.sin(t * .0004 * s.s + s.p));
        cx.fillStyle = '#dbeafe'; cx.beginPath(); cx.arc(s.x, s.y, s.r, 0, 6.29); cx.fill();
      }
      cx.globalAlpha = 1;
      if (!shot && Math.random() < .003) shot = { x: Math.random() * W * .7 + W * .2, y: Math.random() * H * .25, vx: -7 - Math.random() * 4, vy: 4 + Math.random() * 2, life: 1 };
      if (shot) {
        shot.x += shot.vx; shot.y += shot.vy; shot.life -= .02;
        const g = cx.createLinearGradient(shot.x, shot.y, shot.x - shot.vx * 9, shot.y - shot.vy * 9);
        g.addColorStop(0, 'rgba(160,210,255,' + (.9 * Math.max(shot.life, 0)) + ')'); g.addColorStop(1, 'rgba(160,210,255,0)');
        cx.strokeStyle = g; cx.lineWidth = 2; cx.beginPath(); cx.moveTo(shot.x, shot.y); cx.lineTo(shot.x - shot.vx * 9, shot.y - shot.vy * 9); cx.stroke();
        if (shot.life <= 0) shot = null;
      }
      requestAnimationFrame(tick);
    })(0);
  }

  function build() {
    if (!document.body) return;
    const file = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    if (APP_PAGES.indexOf(file) > -1) {
      root.classList.add('hz-app');
      if (!document.querySelector('.hz-backlink')) {
        const back = document.createElement('a');
        back.className = 'hz-backlink'; back.href = 'home.html';
        back.textContent = '\u2190 HamzaEditz Home';
        document.body.appendChild(back);
      }
      return;
    }
    fonts();
    if (file !== 'index.html' && file !== '') starfield();
    if (file === 'index.html' || file === '') return; /* splash: standalone */
    manifestLink();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
