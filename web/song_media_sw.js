// Service Worker for offline song playback on the web build.
//
// Native builds download song audio to real files (see
// lib/services/song_download_io.dart). A browser has no equivalent —
// there is no managed file system, and the full catalogue is ~2.5 GB,
// far past what a tab may keep. So the web story is deliberately
// different and weaker: media the user has ALREADY PLAYED is kept in
// a Cache Storage bucket and served from there next time, including
// offline.
//
// The difference matters and the UI says so rather than showing a
// "Downloaded" tick the browser can revoke: Cache Storage is evictable
// under storage pressure, and the quota belongs to the browser, not to
// us. `navigator.storage.persist()` upgrades that to best-effort
// durable, which is the most a page can ask for.
//
// Scope: only `/song-media/*` — the same-origin proxy path every web
// playback already goes through (see the netlify.toml redirects, added
// because audioplayers_web forces crossOrigin and the three church
// servers send no CORS headers). App shell caching is left to
// Flutter's own generated service worker; this one deliberately does
// not touch it.

const CACHE = 'song-media-v1';
const PREFIX = '/song-media/';

self.addEventListener('install', (event) => {
  // Take over as soon as installed. There is no old version of this
  // worker whose in-flight requests need protecting — it only ever
  // serves media — so waiting would just delay offline support by a
  // navigation.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // Drop caches from older versions of this worker.
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((n) => n.startsWith('song-media-') && n !== CACHE)
          .map((n) => caches.delete(n)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  if (!url.pathname.startsWith(PREFIX)) return;

  // Range requests are how an <audio> element seeks, and a cached
  // 200 cannot answer a 206. Rather than reimplement range slicing,
  // let those go to the network — the initial full-body request is
  // the one worth caching, and it is the one that makes a track play
  // offline at all.
  if (event.request.headers.has('range')) return;

  event.respondWith(
    (async () => {
      const cache = await caches.open(CACHE);
      const hit = await cache.match(event.request);
      if (hit) return hit;

      const response = await fetch(event.request);
      // Only cache a complete, successful body. A 206 or an opaque
      // error response would poison the cache with something that
      // cannot be replayed.
      if (response.ok && response.status === 200) {
        cache.put(event.request, response.clone()).catch(() => {
          // Quota exceeded, most likely. Playback still works from
          // the network response we are about to return, so a failed
          // cache write is not worth surfacing.
        });
      }
      return response;
    })(),
  );
});

// Let the app ask for specific media to be cached ahead of time, and
// report or clear what is stored.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  const reply = (payload) => {
    if (event.ports && event.ports[0]) event.ports[0].postMessage(payload);
  };

  if (data.type === 'cache-media' && Array.isArray(data.urls)) {
    event.waitUntil(
      (async () => {
        const cache = await caches.open(CACHE);
        let stored = 0;
        let failed = 0;
        for (const url of data.urls) {
          try {
            // Sequential on purpose: these are multi-megabyte files
            // and firing hundreds in parallel would stall the tab and
            // hammer the church's servers.
            const existing = await cache.match(url);
            if (existing) {
              stored++;
              continue;
            }
            await cache.add(url);
            stored++;
          } catch (e) {
            failed++;
          }
        }
        reply({ type: 'cache-media-done', stored, failed });
      })(),
    );
  }

  if (data.type === 'media-usage') {
    event.waitUntil(
      (async () => {
        const cache = await caches.open(CACHE);
        const keys = await cache.keys();
        let bytes = 0;
        for (const req of keys) {
          const res = await cache.match(req);
          if (!res) continue;
          const len = res.headers.get('content-length');
          if (len) bytes += parseInt(len, 10) || 0;
        }
        reply({ type: 'media-usage', count: keys.length, bytes });
      })(),
    );
  }

  if (data.type === 'clear-media') {
    event.waitUntil(
      (async () => {
        await caches.delete(CACHE);
        reply({ type: 'clear-media-done' });
      })(),
    );
  }
});
