// YsWords kill-switch service worker.
//
// 2026-08-24: THIS FILE'S CONTENT NO LONGER SHIPS. `flutter build web`
// on Flutter 3.44 overwrites build/web/flutter_service_worker.js with
// its own 784-byte stub (see WebServiceWorker in flutter_tools) — a
// stub that does the same job as everything below: skipWaiting,
// unregister, reload the tab. Verified by diffing this file against
// build/web/flutter_service_worker.js after a build. Nothing registers
// that URL any more either, because web/flutter_bootstrap.js drops the
// `serviceWorkerSettings` argument; it stays deployed purely as a
// tombstone for browsers still polling it from an old deploy. The app's
// real worker is web/app_shell_sw.js. Kept here so the URL still
// resolves in `flutter run -d chrome`, where the build's overwrite does
// not happen.
//
// We no longer use a service worker — `flutter build web --pwa-strategy=none`
// stops generating one, and Netlify's no-cache headers handle freshness.
// But many users have an OLD Flutter service worker installed from earlier
// deploys, and that SW would keep serving stale HTML+JS forever because:
//   • It checks /flutter_service_worker.js for updates on every nav.
//   • If we just delete the file, that fetch 404s → Chrome thinks
//     "no update" → keeps the old SW alive indefinitely → user never
//     gets the new build no matter how many times they reload.
//
// So we replace the URL with this script instead. When a stale browser
// fetches it for an update check, the new bytes trigger SW replacement:
//   1. install → skipWaiting() so the new SW activates without waiting
//      for every tab to close (the default lifecycle).
//   2. activate → claim all controlled clients, wipe every cache the
//      old SW built up, unregister this SW, then reload each client.
//   3. fetch → pass-through; we never want to intercept anything from
//      this point onward, even before the tab reloads.
//
// After one activation, the user has no SW and no app caches. Every
// future visit is a clean HTTP fetch. The file can stay deployed
// forever as a tombstone — it does nothing on a fresh client.

self.addEventListener('install', (event) => {
  // Don't wait for the old SW to release every tab — take over now.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        // Claim every tab the old SW was controlling, so we can
        // unregister and reload them without waiting for the user
        // to navigate away.
        await self.clients.claim();
      } catch (_) {}

      // Nuke every cache bucket the old SW (or this one) ever made.
      try {
        const keys = await caches.keys();
        await Promise.all(keys.map((k) => caches.delete(k).catch(() => {})));
      } catch (_) {}

      // Unregister this service worker. Future page loads see no SW
      // controlling them, fetches go straight to the network, and
      // Netlify's cache headers do the rest.
      try {
        await self.registration.unregister();
      } catch (_) {}

      // Reload each currently-claimed tab so the user immediately
      // lands on a network-fetched, SW-free session.
      try {
        const clients = await self.clients.matchAll({ type: 'window' });
        for (const client of clients) {
          if ('navigate' in client) {
            client.navigate(client.url);
          }
        }
      } catch (_) {}
    })(),
  );
});

// Pass through every fetch. Belt-and-suspenders in case `unregister`
// fails on some exotic browser — at least we never serve a stale
// response from this worker.
self.addEventListener('fetch', (event) => {
  // Intentionally not calling event.respondWith — defaults to network.
  return;
});
