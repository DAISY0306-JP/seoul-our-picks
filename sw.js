// Keeps the lock screen, the encrypted trip (app.enc), the Supabase library, icons and fonts on the phone,
// so the app still opens with no signal. Supabase API calls are never cached.
const CACHE = "ourpicks-v1";
const SHELL = ["./", "index.html", "qr.html", "app.enc", "manifest.webmanifest",
  "apple-touch-icon.png", "icon-192.png", "icon-512.png", "favicon-32.png"];
const LIB = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";

self.addEventListener("install", e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(SHELL);
    try { await c.add(new Request(LIB, { mode: "no-cors" })); } catch (_) {}
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", e => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

const timeout = (ms) => new Promise(r => setTimeout(r, ms));

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.hostname.endsWith("supabase.co")) return;          // live data: always the network

  if (url.origin === self.location.origin) {
    // Our own files: newest from the network, the saved copy if the network is slow or gone.
    const key = req.mode === "navigate" ? "index.html" : url.pathname.replace(/^.*\//, "") || "index.html";
    e.respondWith((async () => {
      const c = await caches.open(CACHE);
      const net = fetch(req, { cache: "no-store" }).then(r => { if (r.ok) c.put(key, r.clone()); return r; });
      const saved = await c.match(key);
      if (!saved) return net;
      const first = await Promise.race([net.catch(() => null), timeout(4000).then(() => null)]);
      return first || saved;
    })());
    return;
  }

  // Library and fonts: the saved copy first, refreshed in the background.
  if (/(cdn\.jsdelivr\.net|fonts\.googleapis\.com|fonts\.gstatic\.com)$/.test(url.hostname)) {
    e.respondWith((async () => {
      const c = await caches.open(CACHE);
      const saved = await c.match(req, { ignoreVary: true });
      const net = fetch(req).then(r => { if (r.ok || r.type === "opaque") c.put(req, r.clone()); return r; });
      if (saved) { net.catch(() => {}); return saved; }
      return net;
    })());
  }
});
