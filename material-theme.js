(() => {
  const root = document.documentElement;
  const key = 'material-theme';
  const saved = localStorage.getItem(key);
  root.dataset.theme = saved || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');

  const bar = document.createElement('nav');
  bar.className = 'md3-toolbar';
  bar.setAttribute('aria-label', 'Site controls');
  bar.innerHTML = '<a class="md3-home" href="index.html">Home</a><button class="md3-theme-toggle" type="button"></button>';
  document.body.appendChild(bar);

  const button = bar.querySelector('.md3-theme-toggle');
  const update = () => {
    const dark = root.dataset.theme === 'dark';
    button.textContent = dark ? 'Light' : 'Dark';
    button.setAttribute('aria-label', dark ? 'Switch to light theme' : 'Switch to dark theme');
    button.setAttribute('aria-pressed', String(dark));
  };
  button.addEventListener('click', () => {
    root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem(key, root.dataset.theme);
    update();
  });
  update();
})();
