/* HamzaEditz UI v7 — Apple Store glass theme (companion to hamza-ui.css v7).
   The brand header lives ONLY on the tools page (home.html); tool pages
   get no injected header/hero/footer. Full-screen app pages get one tiny
   Home link. This script adds the theme fonts. (The v6 starfield was
   retired in v7 — the light colour wash now lives in hamza-ui.css.) */
(() => {
  const root = document.documentElement;
  root.dataset.theme = 'light';

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
    if (file === 'index.html' || file === '') return; /* splash: standalone */
    manifestLink();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
