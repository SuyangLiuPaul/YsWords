// Custom Flutter bootstrap. Identical to the one `flutter build web`
// generates by default, MINUS the `serviceWorkerSettings` argument.
//
// 2026-08-24 (「网页版安装install也安不上」). The default bootstrap ends in
//
//     _flutter.loader.load({
//       serviceWorkerSettings: { serviceWorkerVersion: "<random>" }
//     });
//
// which makes flutter.js register `/flutter_service_worker.js?v=…` at
// scope '/' on every single load. On Flutter 3.44 that file is no
// longer a real worker: `flutter build web` overwrites it with a
// 784-byte stub that unregisters itself and `client.navigate()`s every
// tab (offline-first generation was removed upstream —
// flutter/flutter#156910 — and `--pwa-strategy` is gone from this
// Flutter, so there is no flag to turn it off).
//
// That registration cannot be allowed to stand next to ours. A scope
// holds ONE script: whichever of the two registers last replaces the
// other, so with both in play every load is a coin toss, and the times
// the stub wins it deletes every Cache Storage bucket (including our
// app shell), unregisters, and force-reloads the tab. Dropping the
// argument here leaves web/app_shell_sw.js the uncontested owner of
// scope '/', which is what makes the app installable at all.
//
// The tool reads this file instead of generating one (see
// WebReleaseBundle in flutter_tools/lib/src/build_system/targets/
// web.dart) and substitutes the two tokens below. Keep both tokens and
// keep the file this small — it is frozen against future changes to
// Flutter's default bootstrap, so the less of that default it restates,
// the less there is to drift. Flutter still emits the unregistering
// stub at /flutter_service_worker.js; nothing registers it now, and
// leaving it deployed is what finally evicts it from browsers that
// installed it from an older deploy.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
