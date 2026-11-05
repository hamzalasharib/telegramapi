/* HamzaEditz UI v5.1 — clean Play Store-style theme (CSS). The brand
   header lives ONLY on the tools page (home.html); tool pages get no
   injected header/hero/footer (user order 2026-11-05). Full-screen
   app pages get one tiny Home link. Light theme only. */
(() => {
  const root = document.documentElement;
  root.dataset.theme = 'light';

const LOGO = '<svg viewBox="0 0 100 100" aria-hidden="true"><defs><linearGradient id="hzlg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#34d399"/><stop offset=".5" stop-color="#22d3ee"/><stop offset="1" stop-color="#a78bfa"/></linearGradient></defs><rect width="100" height="100" rx="26" fill="url(#hzlg)"/><rect x="27" y="25" width="11" height="50" rx="4" fill="#fff"/><rect x="62" y="25" width="11" height="50" rx="4" fill="#fff"/><rect x="38" y="44" width="24" height="11" rx="4" fill="#fff"/><path d="M46 38.5v23l20-11.5z" fill="#0b101d" opacity=".92"/></svg>';

const I = {
    download: '<svg viewBox="0 0 24 24"><g class="hz-anim-arrow"><path d="m7 9 5 5 5-5"/><path d="M12 14V3"/></g><path d="M21 15v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3"/></svg>',
    music: '<svg viewBox="0 0 24 24"><rect class="hz-eq" x="4" y="9" width="3.4" height="9" rx="1.7" fill="#fff" stroke="none"/><rect class="hz-eq e2" x="10.3" y="5" width="3.4" height="13" rx="1.7" fill="#fff" stroke="none"/><rect class="hz-eq e3" x="16.6" y="8" width="3.4" height="10" rx="1.7" fill="#fff" stroke="none"/></svg>',
    image: '<svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="9" cy="9" r="1.6"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/></svg>',
    tv: '<svg viewBox="0 0 24 24"><rect x="2" y="7" width="20" height="14" rx="2.5"/><path d="m17 2-5 5-5-5"/><path class="hz-anim-pulse" d="M10.2 11.2v5.6l4.8-2.8z" fill="#fff" stroke="none"/></svg>',
    book: '<svg viewBox="0 0 24 24"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
    monitor: '<svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2.5"/><path d="M8 21h8"/><path d="M12 17v4"/></svg>',
    send: '<svg viewBox="0 0 24 24"><path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/></svg>',
    camera: '<svg viewBox="0 0 24 24"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3.5"/></svg>',
    shield: '<svg viewBox="0 0 24 24"><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/></svg>',
    search: '<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>',
    zap: '<svg viewBox="0 0 24 24"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
    heart: '<svg viewBox="0 0 24 24"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg>',
    user: '<svg viewBox="0 0 24 24"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    lock: '<svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
    layers: '<svg viewBox="0 0 24 24"><path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/><path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/></svg>',
    phone: '<svg viewBox="0 0 24 24"><rect x="7" y="2" width="10" height="20" rx="2.5"/><path d="M12 18h.01"/></svg>',
    spark: '<svg viewBox="0 0 24 24"><path class="hz-anim-spin" d="M12 3l1.9 5.8L20 10l-6.1 1.2L12 17l-1.9-5.8L4 10l6.1-1.2z"/></svg>'
  };

const PAGES = {
    'tiktok.html': ['download', '#ec4899', '#8b5cf6', 'Download TikTok videos without watermark.'],
    'tiktokmenu.html': ['download', '#ec4899', '#8b5cf6', 'All TikTok tools in one place.'],
    'v2.html': ['download', '#ec4899', '#8b5cf6', 'TikTok downloader — engine 1.'],
    'spotify.html': ['music', '#22c55e', '#0ea5e9', 'Convert Spotify tracks to MP3.'],
    'dhunn.html': ['music', '#f59e0b', '#8b5cf6', 'Free music player with synced lyrics.'],
    'image.html': ['image', '#f43f5e', '#f59e0b', 'Generate AI images from text.'],
    'tvchannels.html': ['tv', '#10b981', '#84cc16', 'Watch live TV channels.'],
    'alltv.html': ['tv', '#10b981', '#84cc16', 'Watch live TV channels.'],
    'hadith.html': ['book', '#eab308', '#f97316', 'Search Hadith by book and chapter.'],
    'quran.html': ['book', '#eab308', '#f97316', 'Read and listen to the Quran.'],
    'rdp-latest.html': ['monitor', '#8b5cf6', '#ec4899', 'Latest free RDP method — video + code.'],
    'rdpmethod.html': ['monitor', '#8b5cf6', '#ec4899', 'Free Windows RDP — step-by-step guide.'],
    'rdp.html': ['monitor', '#8b5cf6', '#ec4899', 'Free Windows RDP setup guide.'],
    'rdp3.html': ['monitor', '#8b5cf6', '#ec4899', 'RDP setup guide.'],
    'rdp_latest.html': ['monitor', '#8b5cf6', '#ec4899', 'Latest free Windows RDP method.'],
    'domicile.html': ['shield', '#22c55e', '#84cc16', 'Verify a Punjab domicile by CNIC.'],
    'jazz-claimer.html': ['zap', '#ef4444', '#f97316', 'Claim daily Jazz Shake N Win rewards.'],
    'smsbomber.html': ['send', '#f97316', '#ef4444', 'Fast SMS utility.'],
    'instagram.html': ['camera', '#d946ef', '#f97316', 'Download Instagram media.'],
    'id.html': ['shield', '#0ea5e9', '#6366f1', 'SheerID verification helper.'],
    'india.html': ['search', '#f59e0b', '#ef4444', 'Phone number lookup.'],
    'paksim.html': ['phone', '#22c55e', '#84cc16', 'Check SIM information.'],
    'vehicledetails.html': ['search', '#f59e0b', '#ef4444', 'Vehicle registration details.'],
    'jazz.html': ['phone', '#ef4444', '#f97316', 'Jazz packages and activation.'],
    'apk.html': ['zap', '#84cc16', '#22c55e', 'Jazz Shake N Win auto claimer.'],
    'ludo.html': ['zap', '#f43f5e', '#8b5cf6', 'Yalla Ludo device lock solution.'],
    'earn.html': ['spark', '#f59e0b', '#84cc16', 'Auto task runner.'],
    'physics.html': ['book', '#38bdf8', '#818cf8', 'PHY101 notes.'],
    'user.html': ['user', '#0ea5e9', '#6366f1', 'View any public TikTok profile.'],
    'vpn.html': ['lock', '#6366f1', '#0ea5e9', 'MsyVpn config decrypt tool.'],
    'sora_remove.html': ['layers', '#a78bfa', '#ec4899', 'Download Sora videos in bulk.'],
    'purpose.html': ['heart', '#f43f5e', '#ec4899', 'A page made for you.'],
    'about.html': ['user', '#0ea5e9', '#6366f1', 'About Hamza Shafiq.']
  };
  const APP_PAGES = ['welcome.html', 'tvchannels.html', 'alltv.html', 'sulu', 'sulu.html', 'spotify'];

  function cleanTitle() {
    let t = (document.title || 'HamzaEditz').replace(/\s*[|–—-]\s*HamzaEditz.*$/i, '').replace(/^HamzaEditz 2\.0\s*[-–—]\s*/i, '').trim();
    return t || 'HamzaEditz';
  }
  function manifestLink() {
    if (!document.querySelector('link[rel="manifest"]')) {
      const l = document.createElement('link');
      l.rel = 'manifest'; l.href = 'manifest.webmanifest';
      document.head.appendChild(l);
    }
  }
  function build() {
    if (!document.body || document.querySelector('.hz-backlink')) return;
    const file = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    if (file === 'index.html' || file === '') return; /* splash: standalone */
    if (file === 'home.html') { manifestLink(); return; } /* tools page keeps its own header */
    if (APP_PAGES.indexOf(file) > -1) {
      root.classList.add('hz-app');
      const back = document.createElement('a');
      back.className = 'hz-backlink'; back.href = 'home.html';
      back.textContent = '\u2190 HamzaEditz Home';
      document.body.appendChild(back);
      return;
    }
    /* Tool pages: NO site header/hero/footer (user order 2026-11-05) —
       the brand header lives only on the tools page (home.html). */
    manifestLink();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build); else build();
})();
