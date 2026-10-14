(() => {
  const root = document.documentElement;
  const saved = localStorage.getItem('material-theme');
  const systemDark = matchMedia('(prefers-color-scheme: dark)').matches;
  root.dataset.theme = saved || (systemDark ? 'dark' : 'light');
  const bar = document.createElement('div');
  bar.className = 'md3-toolbar';
  bar.innerHTML = '<a class="md3-home" href="index.html" aria-label="Go to home">Home</a><button class="md3-theme-toggle" type="button" aria-label="Toggle color theme"></button>';
  document.body.appendChild(bar);
  const button = bar.querySelector('button');
  const update = () => { const dark = root.dataset.theme === 'dark'; button.textContent = dark ? '☀' : '☾'; button.title = dark ? 'Switch to light theme' : 'Switch to dark theme'; };
  button.addEventListener('click', () => { root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark'; localStorage.setItem('material-theme', root.dataset.theme); update(); });
  update();
})();
