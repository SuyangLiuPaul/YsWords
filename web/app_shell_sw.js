'use strict';

// YsWords app-shell service worker — NETWORK FIRST, always.
//
// 2026-08-24, from the user: 「网页版安装install也安不上」 — the web app
// could not be installed. Reproduced in a browser against the live dev
// site: `getRegistrations()` returned 0 after a full load, so Chrome
// never fired `beforeinstallprompt` and the in-app Install button
// correctly reported that nothing was available.
//
// Why the app had no worker at all, in order:
//   • `flutter build web` on Flutter 3.44 ALWAYS overwrites
//     build/web/flutter_service_worker.js with a 784-byte stub whose
//     activate handler calls `self.registration.unregister()` and then
//     `client.navigate()`s every tab. Offline-first worker generation
//     was removed upstream (flutter/flutter#156910) and `--pwa-strategy`
//     no longer exists on this Flutter, so nothing in this repo turned
//     it off — there is simply no Flutter-generated worker to keep.
//   • The generated flutter_bootstrap.js kept registering that stub on
//     every load, so the only worker the app ever had was one that
//     deleted every cache and unregistered itself moments later.
// Installability requires a worker with a fetch handler controlling
// start_url, so the app has to ship its OWN. This is it. See
// web/flutter_bootstrap.js for the half that stops the stub being
// registered on top of us.
//
// WHY NETWORK FIRST — read before changing anything below.
//
// This repo has already lived through the failure a caching worker
// causes: a STALE SERVICE WORKER served old HTML/JS to returning users
// long after a deploy, and the shell could not be shifted no matter how
// often they reloaded. The self-heal block in web/index.html and the
// `no-cache` headers in netlify.toml both exist because of that
// incident. So this worker never answers from cache while the network
// is reachable: every request goes to the network first, and the cache
// is consulted ONLY when the fetch throws. Cache-first and
// stale-while-revalidate are exactly the pattern that burned us, and
// must not be reintroduced here — offline support is a nice-to-have,
// serving an online user a stale shell is a production incident.

// The `?v=` on our own script URL is the build's version.json version,
// set by the registration in web/index.html. A deploy that bumps the
// version therefore (a) changes this script's URL, which is what makes
// the browser install a new worker at all, and (b) rotates the cache
// name below, so the previous build's shell is dropped in activate
// rather than lingering as an offline fallback for a build that no
// longer exists.
const SHELL_VERSION = (function () {
  try {
    return new URL(self.location.href).searchParams.get('v') || 'dev';
  } catch (_) {
    return 'dev';
  }
})();
const CACHE_PREFIX = 'yswords-shell-';
const CACHE_NAME = CACHE_PREFIX + SHELL_VERSION;

// MINIMAL shell only. main.dart.js (9.93 MB), the canvaskit bundle and
// the bundled Bible JSONs (nasb.json alone is 6.88 MB — all measured in
// build/web, 2026-08-24) are deliberately absent: install
// fails atomically if any one entry fails, and pre-caching tens of
// megabytes on first paint is both a slow install and the most likely
// way for install to fail outright. Those large files still become
// available offline the ordinary way — through the runtime copy in
// `copyToCache` below, after the user has actually loaded them once.
const SHELL_URLS = [
  'index.html',
  'manifest.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
];

// Resolved against the script URL, so the `?v=` query is dropped:
// '/app_shell_sw.js?v=1.4.140' + 'index.html' → '/index.html'.
// Every SPA navigation is stored under this one key — Netlify's
// `/*  /index.html  200` rewrite means every route returns the same
// shell, and a navigate-mode Request cannot be used as a cache key at
// all (`cache.put` rejects with "Request mode must not be navigate").
const INDEX_URL = new URL('index.html', self.location.href).toString();

// Paths this worker must never see, let alone answer:
//   /song-media/  the netlify.toml proxy in front of the four church
//                 media hosts. ~5 MB mp3s served with Range requests;
//                 offline audio is handled by Cache Storage directly in
//                 lib/services/song_download_web.dart, which does not
//                 want a fetch handler in the middle of it.
//   /api/, /.netlify/  the Gemini AI-search function. Dynamic, and a
//                 cached answer to a different question is worse than
//                 no answer.
//   /__/auth/     the Firebase auth reverse proxy. Credential flow —
//                 nothing here belongs in a cache.
const BYPASS_PREFIXES = ['/song-media/', '/api/', '/.netlify/', '/__/auth/'];

// Ceiling on what the runtime copy will store — a backstop against one
// pathological response, not a budget. Measured in build/web on
// 2026-08-24: main.dart.js 9.93 MB, nasb.json 6.88 MB,
// biblexg-v2.json 2.15 MB. main.dart.js has to be storable or offline
// is a blank page (verified: with the server stopped, a deep SPA route
// still booted precisely because main.dart.js was in this cache), so
// the ceiling sits above it.
//
// Advisory by nature: it reads the DECLARED content-length, which is
// absent on a chunked response and is the COMPRESSED size when the
// server gzips — so it under-counts rather than over-counts. Cache
// Storage quota is the real limit, and the browser evicts under
// pressure; nothing here is ever load-bearing, since a miss just means
// one more network fetch.
const RUNTIME_MAX_BYTES = 16 * 1024 * 1024;

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      try {
        const cache = await caches.open(CACHE_NAME);
        // Added one by one, each with its own catch: `cache.addAll`
        // rejects the whole install if a single entry 404s, and a
        // failed install means no worker, which means no install
        // prompt — the very bug being fixed here. Offline support is
        // best-effort; installability is not.
        await Promise.all(
          SHELL_URLS.map((u) =>
            cache
              .add(new Request(u, { cache: 'reload' }))
              .catch(() => {}),
          ),
        );
      } catch (_) {}
      // Take over immediately. Safe precisely because we are network
      // first: a newly activated worker cannot serve anything staler
      // than what the network returns.
      try {
        await self.skipWaiting();
      } catch (_) {}
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        const keys = await caches.keys();
        await Promise.all(
          keys
            // ONLY our own older buckets. The `song-media-` caches hold
            // audio the user explicitly asked to keep offline and are
            // not ours to delete — the same exemption the sweep in
            // web/index.html makes.
            .filter((k) => k.indexOf(CACHE_PREFIX) === 0 && k !== CACHE_NAME)
            .map((k) => caches.delete(k).catch(() => {})),
        );
      } catch (_) {}
      try {
        await self.clients.claim();
      } catch (_) {}
      // Deliberately NO client.navigate() here. That is what Flutter's
      // unregistering stub does, and doing it on activate turns every
      // worker replacement into a forced reload mid-read.
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Everything below is a reason to leave the request entirely alone —
  // no respondWith, so the browser performs its own default fetch and
  // this worker is not in the path at all.
  if (request.method !== 'GET') return;

  let url;
  try {
    url = new URL(request.url);
  } catch (_) {
    return;
  }

  // Cross-origin is never ours: the church media hosts, YouTube
  // embeds, gstatic/CanvasKit, Firebase, Google Fonts. Intercepting
  // them buys nothing and risks opaque responses filling the quota.
  if (url.origin !== self.location.origin) return;

  if (BYPASS_PREFIXES.some((p) => url.pathname.indexOf(p) === 0)) return;

  // Range requests (media seeking) must reach the network untouched —
  // Cache Storage does not do partial content.
  if (request.headers.has('range')) return;

  // DevTools "offline" checkbox + Chrome's back/forward cache probe
  // issue only-if-cached requests we are not allowed to answer.
  if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') {
    return;
  }

  event.respondWith(networkFirst(request, request.mode === 'navigate'));
});

async function networkFirst(request, isNavigation) {
  // NETWORK FIRST. The fetch comes before any cache read on purpose —
  // see the header comment. An online user always gets the bytes the
  // server just handed us, deploy-fresh, exactly as if this worker did
  // not exist.
  try {
    const response = await fetch(request);
    if (response && response.ok) {
      copyToCache(request, response, isNavigation);
    }
    return response;
  } catch (err) {
    // Network unreachable — only now does the cache come into play.
    // Scoped to OUR bucket (`caches.match` would also search the
    // `song-media-` caches, which answer a different question).
    try {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(isNavigation ? INDEX_URL : request);
      if (cached) return cached;
    } catch (_) {}
    // Nothing cached: let the failure surface as a normal network
    // error rather than inventing a response.
    throw err;
  }
}

// Fire-and-forget refresh of the offline copy. Never awaited by the
// response path, so a cache write can never delay or fail a live
// request.
function copyToCache(request, response, isNavigation) {
  try {
    // 'basic' == same-origin and readable. Opaque/CORS responses have
    // no useful body for us and count fully against the quota.
    if (response.type !== 'basic') return;
    const declared = Number(response.headers.get('content-length') || '0');
    if (declared > RUNTIME_MAX_BYTES) return;
    const copy = response.clone();
    const key = isNavigation ? INDEX_URL : request;
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.put(key, copy))
      .catch(() => {});
  } catch (_) {}
}
