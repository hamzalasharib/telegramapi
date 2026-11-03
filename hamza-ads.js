/* ============================================================
   HamzaEditz — Monetag ads (loaded on every page EXCEPT home)
   Zone 12186361 — al5sm.com tag (added 2026-11-04 on user order)
   Copy-button Direct Link: paste the Monetag Direct Link URL
   into DIRECT_LINK below and Copy buttons will open it too.
   ============================================================ */
(() => {
  /* Monetag tag — exactly as provided by the user */
  (function(s){s.dataset.zone='12186361',s.src='https://al5sm.com/tag.min.js'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')));

  const DIRECT_LINK = ""; // Monetag Direct Link for Copy buttons (optional)

  /* Called by Copy buttons (e.g. on the RDP code page): opens the
     Direct Link ad in a new tab when one is configured. */
  window.hzOnCopyAction = function () {
    if (DIRECT_LINK && /^https:\/\//.test(DIRECT_LINK)) {
      window.open(DIRECT_LINK, '_blank', 'noopener');
    }
  };
})();
