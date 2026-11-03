/* HamzaEditz 2.0 — Shared UI v3 toolbar + theme (same design as hamzaeditz.tech) */
(() => {
  const root = document.documentElement;
  const saved = localStorage.getItem('hamza-theme') || localStorage.getItem('material-theme');
  root.dataset.theme = saved || 'dark';
  const LOGO = '<svg viewBox="0 0 100 100" aria-hidden="true"><defs><linearGradient id="hzlg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#34d399"/><stop offset=".5" stop-color="#22d3ee"/><stop offset="1" stop-color="#a78bfa"/></linearGradient></defs><rect width="100" height="100" rx="26" fill="url(#hzlg)"/><rect x="27" y="25" width="11" height="50" rx="4" fill="#fff"/><rect x="62" y="25" width="11" height="50" rx="4" fill="#fff"/><rect x="38" y="44" width="24" height="11" rx="4" fill="#fff"/><path d="M46 38.5v23l20-11.5z" fill="#0b101d" opacity=".92"/></svg>';
  const SUN = '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>';
  const MOON = '<svg viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
  const build = () => {
    if (!document.body || document.querySelector('.md3-toolbar')) return;
    const bar = document.createElement('div');
    bar.className = 'md3-toolbar';
    bar.innerHTML = '<a class="md3-brand" href="index.html" aria-label="HamzaEditz home">' + LOGO + '<span>HamzaEditz</span></a>' +
      '<a class="md3-home" href="index.html">Home</a>' +
      '<a class="md3-home" href="index.html#tools">Tools</a>' +
      '<button class="md3-theme-toggle" type="button" aria-label="Toggle color theme"></button>';
    document.body.appendChild(bar);
    const button = bar.querySelector('.md3-theme-toggle');
    const update = () => { const dark = root.dataset.theme === 'dark'; button.innerHTML = dark ? SUN : MOON; button.title = dark ? 'Switch to light theme' : 'Switch to dark theme'; };
    button.addEventListener('click', () => {
      root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
      localStorage.setItem('hamza-theme', root.dataset.theme);
      update();
    });
    update();
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
