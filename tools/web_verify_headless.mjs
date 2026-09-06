#!/usr/bin/env node
// Headless-Chrome verification harness for the three web behaviours that
// shipped 2026-09-02 argued from tests and source rather than observed in
// a browser:
//
//   1. URL routing  — docs/url-routing-plan.md Stage 5 gave `/settings/ai`,
//                     `/library/bookmarks`, `/evidence?book=&chapter=` and
//                     `/songs/:id/score` real addresses. Nobody had cold-
//                     loaded one. The queue item's ORIGINAL bug — "the
//                     address bar still read Micah 2:1 while reading a
//                     sermon" — had never been reproduced or shown fixed
//                     against a running build either, nor had browser
//                     Back/Forward been pressed.
//   2. YouTube      — lib/widgets/youtube_embed_web.dart claims the iframe
//                     now carries `enablejsapi=1` + `origin`, that the page
//                     posts `listening` on load and 10x at 500 ms, that the
//                     player answers with `currentTime` frames, and that a
//                     language switch re-mounts with `?start=N`. None of
//                     that round trip had been watched happen.
//   3. Typography   — lib/pages/sermon_detail_page.dart's `_SermonBody`
//                     moved the paragraph gap from 22.0 pt to
//                     `fontSize * 0.3` and gave every paragraph a 2-em
//                     first-line indent. Nobody had looked at it.
//
// Sibling of tools/boot_trap_headless_repro.mjs and built to the same
// rule: **zero dependencies**. Node 24's built-in `fetch` and `WebSocket`
// drive Chrome's DevTools Protocol directly, and `node:http` serves the
// build — no puppeteer, no static-server package, nothing added to this
// repo's dependency graph.
//
//     node tools/web_verify_headless.mjs [--root build/web] [--out DIR]
//                                        [--steps steps.json]
//                                        [all|routes|sermon|history|youtube|typography]
//
// Defaults: `--root build/web`, `--out build/web-verify`, subcommand `all`.
// Subcommands:
//
//   routes      the four owed addresses, cold-loaded, plus a bare
//               `/settings` control for the `:section` slug
//   sermon      the original "address bar still reads Micah 2:1" bug,
//               then browser Back/Forward. Runs TWICE: once with a Bible
//               position planted, once with nothing planted at all, so a
//               Back result cannot be an artifact of the planting setup
//   history     `sermon` PLUS `bible` — every browser-history case there
//               is, which is what the two web-history queue items ask for
//   bible       the Bible reader's own history: does an in-app chapter
//               change add a browser entry, and what does ONE Back do to
//               the raw `pushState` entries `_writeStateToUrl` wrote
//   youtube     the enablejsapi handshake and the language switch
//   typography  sermon 004 at 402x874, captured, with the paragraph gap
//               measured off the live layout
//   picker      the Bible-version picker driven the way assistive
//               technology drives it — the same coordinates replayed with
//               Flutter's accessibility tree ON and OFF, with the URL's
//               `?v=` as the oracle in both
//
// 2026-09-03: this is now also a REGRESSION GATE, not only a report.
// Two of the things it found have been fixed — `/settings/:section` not
// scrolling, and one Back unwinding two pages — and neither is reachable
// from `flutter test` (a lazily-built `ListView` in a real release
// bundle; a `popstate` listener behind `dart:js_interop`). So the
// process now EXITS 1 when either regresses. See the "regression gate"
// block at the bottom of `main()` for exactly what is gated and what is
// deliberately only reported (anything network-dependent, and Forward,
// which cannot work in single-entry history mode).
//
// Artifacts (screenshots + `results.json`) land in `--out`. Build the
// bundle the way tools/release_web.sh does before running:
//
//     V=$(grep -m1 ^version: pubspec.yaml | sed 's/^version: *//' | cut -d+ -f1)
//     ~/flutter/bin/flutter build web --release --no-web-resources-cdn \
//         --dart-define=APP_VERSION=$V
//
// LOCAL ONLY, by construction. There is no origin argument: this harness
// serves `--root` from 127.0.0.1 on an ephemeral port and can only ever
// point Chrome at that. It plants localStorage and drives clicks; it must
// never touch yahwehword.com / yswords*.netlify.app, and it cannot.
//
// ── Two things every case here has to work around, both real behaviour ──
//
// (a) **CanvasKit paints text into a <canvas>.** `document.body.innerText`
//     is empty on a perfectly healthy boot, so "did the right page load"
//     cannot be answered from the DOM the way it could for an HTML app.
//     The answer used instead is Flutter's own accessibility tree: click
//     the `<flt-semantics-placeholder>` the engine ships for screen-reader
//     users and the framework mirrors every rendered widget into
//     `<flt-semantics-host>` as positioned DOM nodes carrying their text.
//     That gives BOTH the page-identity oracle and — via
//     `getBoundingClientRect()` — real screen coordinates to click, which
//     is how this harness drives a canvas app at all. Clicks go through
//     `Input.dispatchMouseEvent` at those coordinates rather than
//     `element.click()`, so they run Flutter's own hit test instead of
//     relying on a DOM handler that only `role=button` nodes have.
//
// (b) **A fresh profile means the first-run onboarding tutorial opens.**
//     Stage 3 of the routing work hit a stale-service-worker trap, so
//     every navigation below gets its OWN throwaway Chrome profile
//     (`mkdtemp`, new `--user-data-dir`, new debug port, killed after).
//     The price is that `onboarding.seen.v3` is unset every single time
//     and the tour dialog opens over whatever page loaded. That is not
//     noise to be suppressed — it is the exact shape main.dart:1261-1269
//     says once broke the address bar (a `PopupRoute` opening over a
//     registered route reset UrlSyncService's notion of the current
//     route, and the Bible writer took the URL back). So the cases below
//     load cold with NOTHING planted, record what the tour did to the
//     hash, dismiss it by clicking "Skip", and only then assert. The one
//     exception is `sermon`, which plants Micah 2 on purpose — see there.
//
// (c) **The server has to honour netlify.toml's /song-media/* proxy.**
//     See `loadSongMediaProxies`. Without it `/#/songs/:id/score` fails
//     in a way that looks like a routing bug and is not one.
'use strict';

import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join, extname, resolve as resolvePath } from 'node:path';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// ── argv ─────────────────────────────────────────────────────────────

const VALUE_FLAGS = new Set(['--root', '--out', '--steps', '--lang']);
const argv = process.argv.slice(2);
function flag(name, dflt) {
  const i = argv.indexOf(name);
  return i < 0 ? dflt : argv[i + 1];
}
const WEB_ROOT = resolvePath(flag('--root', 'build/web'));
const OUT_DIR = resolvePath(flag('--out', 'build/web-verify'));
// Every profile is throwaway (`mkdtemp`, see (b) below) and previously
// rode whatever locale the OS gave it — `Browser.launch` pinned the
// window size but not this. 2026-09-06: that gap is what let the
// `runYoutube` `languageChip` regex collide with `_wholeSeriesRow`'s
// "中文" button undetected — nobody could reproduce a Chinese profile to
// find out. Default stays the English the harness has always run in;
// pass `--lang zh-Hans` (or any BCP-47 tag Chrome accepts) to force a
// script for one run.
const LANG = flag('--lang', 'en-US');
// `picker` only. Without it that case MEASURES the picker's coordinates
// off the accessibility tree and writes `steps.json` into `--out`; with
// it, the case REPLAYS exactly those pixels instead. That is how the
// same coordinates can drive a fixed build and a broken one, so a
// difference between them cannot be a difference in where the harness
// aimed. See "case 9" below.
const STEPS_IN = flag('--steps', null);
const positional = argv.filter((a, i) =>
  !a.startsWith('--') && !VALUE_FLAGS.has(argv[i - 1]));
const CMD = positional[0] || 'all';
const KNOWN = ['all', 'routes', 'sermon', 'history', 'youtube', 'typography',
               'chronology', 'bible', 'version', 'picker'];
if (!KNOWN.includes(CMD)) {
  console.error(`Unknown subcommand ${JSON.stringify(CMD)}. One of: ${KNOWN.join(', ')}`);
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Every clickText() call across every case, in order — see clickText's own
// comment for why this exists. Written into results.json as `out.clicks` so
// an ambiguous match is visible in the artifact instead of only in a
// terminal that has already scrolled away.
const CLICK_LOG = [];

// ── static server ────────────────────────────────────────────────────
//
// Mirrors what Netlify does for this SPA closely enough for the cases
// here: exact file if it exists, otherwise index.html (the `_redirects`
// fallback). Hash routes never reach the server at all — the fragment is
// client-side — but /assets/**, /canvaskit/** and the deferred JS parts
// do, and a 404 on any of them is a boot failure, so unknown paths fall
// through to index.html rather than 404ing silently.

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.gif': 'image/gif', '.webp': 'image/webp', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.wasm': 'application/wasm',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff': 'font/woff',
  '.woff2': 'font/woff2', '.bin': 'application/octet-stream',
  '.xml': 'application/xml; charset=utf-8',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.symbols': 'application/octet-stream',
};

/// The `/song-media/<source>/*` proxy, read out of `netlify.toml` rather
/// than hard-coded.
///
/// Not a nicety. `SongPlayerService.resolvePlaybackUrl` rewrites every
/// song asset URL on web to a root-relative `/song-media/cdc/…` path,
/// because `audioplayers_web` hard-codes `crossOrigin='anonymous'` and
/// the churches' servers send no `Access-Control-Allow-Origin`. Netlify
/// turns those paths back into upstream fetches. A plain static server
/// falls them through to index.html, `pdfrx` gets HTML where it expected
/// a PDF, and `/#/songs/:id/score` reports "Failed to open document:
/// FPDF_ERR_FORMAT (3)" — which looks exactly like a broken route and is
/// not one. Found the first time this harness ran; mirroring the rule is
/// what makes that case's result mean anything.
async function loadSongMediaProxies(repoRoot) {
  const toml = await readFile(join(repoRoot, 'netlify.toml'), 'utf8')
    .catch(() => '');
  const map = new Map();
  const re = /from\s*=\s*"\/song-media\/([^/"]+)\/\*"\s*\n\s*to\s*=\s*"(https:\/\/[^"]+)\/:splat"/g;
  let m;
  while ((m = re.exec(toml))) map.set(m[1], m[2]);
  return map;
}

// ── fault injection ──────────────────────────────────────────────────
//
// The version-switch case (case 8) has to reproduce a FAILING or SLOW
// asset load on demand: "forever if the load throws" is the seam
// `main_provider.dart`'s `renderedVersion` comment names, and waiting
// for a flaky network to supply one is not a reproduction. Keys are
// exact request paths (`/assets/assets/biblexg-v2.json`); the value says
// what to do and, when `remaining` is a number, for how many more
// requests. Empty for every other case, so nothing else changes.
const FAULTS = new Map();

function faultFor(path) {
  const f = FAULTS.get(path);
  if (!f) return null;
  if (typeof f.remaining === 'number') {
    if (f.remaining <= 0) return null;
    f.remaining -= 1;
  }
  f.hits = (f.hits || 0) + 1;
  return f;
}

function startServer(root, songMedia = new Map()) {
  return new Promise((resolve, reject) => {
    const srv = createServer(async (req, res) => {
      try {
        let p = decodeURIComponent(req.url.split('?')[0]);
        if (p.includes('..')) { res.writeHead(400); return res.end('no'); }
        const fault = faultFor(p);
        if (fault) {
          if (fault.delayMs) await sleep(fault.delayMs);
          if (fault.status) {
            res.writeHead(fault.status, { 'cache-control': 'no-store' });
            return res.end('injected fault');
          }
          if (fault.abort) { return req.socket.destroy(); }
        }
        if (p.startsWith('/song-media/')) {
          const [, , source, ...rest] = p.split('/');
          const upstream = songMedia.get(source);
          if (!upstream) { res.writeHead(404); return res.end('no such song-media source'); }
          const target = upstream + '/' + rest.join('/');
          const up = await fetch(target).catch((e) => ({ ok: false, status: 599, err: e }));
          if (!up || !up.ok) {
            res.writeHead(up?.status || 502);
            return res.end('song-media upstream failed: ' + target);
          }
          const body = Buffer.from(await up.arrayBuffer());
          res.writeHead(200, {
            'content-type': up.headers.get('content-type') || 'application/octet-stream',
            'access-control-allow-origin': '*',
            'cache-control': 'no-store',
          });
          return res.end(body);
        }
        if (p.endsWith('/')) p += 'index.html';
        let f = join(root, p);
        let s = await stat(f).catch(() => null);
        if (s && s.isDirectory()) {
          f = join(f, 'index.html');
          s = await stat(f).catch(() => null);
        }
        if (!s) { f = join(root, 'index.html'); s = await stat(f).catch(() => null); }
        if (!s) { res.writeHead(404); return res.end('not found'); }
        const buf = await readFile(f);
        res.writeHead(200, {
          'content-type': MIME[extname(f)] || 'application/octet-stream',
          // No-store everywhere: the harness relies on each fresh profile
          // fetching this build, not a memory-cached earlier one.
          'cache-control': 'no-store',
        });
        res.end(buf);
      } catch (e) { res.writeHead(500); res.end(String(e)); }
    });
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => resolve({ srv, port: srv.address().port }));
  });
}

// ── CDP ──────────────────────────────────────────────────────────────

class Cdp {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = [];
    this.ready = new Promise((res, rej) => {
      this.ws.addEventListener('open', () => res());
      this.ws.addEventListener('error', (e) => rej(e));
    });
    this.ws.addEventListener('message', (ev) => {
      const m = JSON.parse(ev.data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        if (m.error) reject(new Error(JSON.stringify(m.error)));
        else resolve(m.result);
      } else if (m.method) {
        for (const l of this.listeners) l(m.method, m.params);
      }
    });
  }
  send(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  on(fn) { this.listeners.push(fn); }
  close() { try { this.ws.close(); } catch { /* already gone */ } }
}

// ── the page-side instrumentation ────────────────────────────────────
//
// Injected with Page.addScriptToEvaluateOnNewDocument, so it is in place
// before ANY page script — including flutter_bootstrap.js — on every
// document the tab loads.
//
// `__ysOut` is the half nothing else can see. `_armPositionReporting`
// calls `frame.contentWindow.postMessage(...)` on a CROSS-ORIGIN window;
// there is no event, no network request and no console line when that
// happens, so the only way to witness the handshake from outside the
// player is to intercept the property access itself. Overriding the
// `contentWindow` getter on HTMLIFrameElement.prototype to hand back a
// Proxy is legal here specifically because the HTML spec defines
// cross-origin properties as `configurable: true` — a Proxy `get` trap
// may therefore return a different `postMessage` without tripping an
// invariant. Everything else falls through untouched, inside a try so a
// disallowed cross-origin read returns undefined instead of throwing
// into Flutter.

const INSTRUMENT = `
  window.__ysConsole = [];
  (function () {
    ['log', 'warn', 'error', 'info'].forEach(function (m) {
      var orig = console[m] ? console[m].bind(console) : function () {};
      console[m] = function () {
        try {
          window.__ysConsole.push(m + ': ' + Array.prototype.map
            .call(arguments, String).join(' ').slice(0, 1200));
        } catch (x) { /* ignore */ }
        return orig.apply(null, arguments);
      };
    });
  })();
  window.__ysErrors = [];
  window.__ysOut = [];   // postMessage() calls this page MADE into an iframe
  window.__ysIn = [];    // message events this page RECEIVED
  window.__ysHashLog = [];
  window.addEventListener('error', function (e) {
    window.__ysErrors.push('window.onerror: ' + e.message + ' @ ' +
      e.filename + ':' + e.lineno + ':' + e.colno);
  });
  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason;
    window.__ysErrors.push('unhandledrejection: ' +
      (r && r.stack ? r.stack : String(r)));
  });
  window.addEventListener('message', function (e) {
    try {
      window.__ysIn.push({
        origin: e.origin,
        t: Date.now(),
        data: (typeof e.data === 'string') ? e.data.slice(0, 500)
              : ('[' + (e.data === null ? 'null' : typeof e.data) + ']'),
      });
    } catch (x) { /* ignore */ }
  }, true);
  (function () {
    var d = Object.getOwnPropertyDescriptor(
      HTMLIFrameElement.prototype, 'contentWindow');
    if (!d || !d.get) return;
    Object.defineProperty(HTMLIFrameElement.prototype, 'contentWindow', {
      configurable: true,
      enumerable: d.enumerable,
      get: function () {
        var w = d.get.call(this);
        if (!w) return w;
        var host = this;
        try {
          return new Proxy(w, {
            get: function (t, p) {
              if (p === 'postMessage') {
                return function (msg, target) {
                  try {
                    window.__ysOut.push({
                      src: host.getAttribute('src'),
                      msg: String(msg).slice(0, 400),
                      target: String(target),
                      t: Date.now(),
                    });
                  } catch (e) { /* ignore */ }
                  return t.postMessage(msg, target);
                };
              }
              try { return Reflect.get(t, p); } catch (e) { return undefined; }
            },
          });
        } catch (e) { return w; }
      },
    });
  })();
  // Every History API call and every popstate, in order. This is the
  // decisive instrument for Back: whether an in-app navigation PUSHES a
  // history entry or REPLACES the current one is the difference between
  // "Back returns to the previous page" and "Back leaves the app", and
  // docs/url-routing-plan.md §5 asserts the former from reading the
  // code. Chrome's own Page.getNavigationHistory reports a merged view
  // that cannot distinguish the two after the fact; this can.
  window.__ysHistory = [];
  (function () {
    var ps = History.prototype.pushState;
    var rs = History.prototype.replaceState;
    // The STATE argument is recorded, not just the url. It is the only
    // thing that says which BrowserHistory the engine is running:
    // {"origin":true} / {"flutter":true} is SingleEntryBrowserHistory
    // tagging its two entries, {"serialCount":N,...} is
    // MultiEntriesBrowserHistory, and a bare null is this app's own
    // _writeStateToUrl writing an entry the engine does not know about.
    // Reading history.state at the end of a walk cannot tell them
    // apart -- whoever wrote last wins -- so it is captured per call.
    // (No backticks anywhere in here: this whole block is itself a
    // template literal, and one would end it.)
    var enc = function (v) {
      try { return JSON.stringify(v); } catch (e) { return '<unencodable>'; }
    };
    History.prototype.pushState = function (s, t, u) {
      try { window.__ysHistory.push({ op: 'pushState', url: String(u), state: enc(s), t: Date.now() }); } catch (e) {}
      return ps.apply(this, arguments);
    };
    History.prototype.replaceState = function (s, t, u) {
      try { window.__ysHistory.push({ op: 'replaceState', url: String(u), state: enc(s), t: Date.now() }); } catch (e) {}
      return rs.apply(this, arguments);
    };
    window.addEventListener('popstate', function (e) {
      try { window.__ysHistory.push({ op: 'popstate', url: location.hash, state: enc(e.state), t: Date.now() }); } catch (e2) {}
    });
  })();
  // Poll the fragment. The bug this harness exists to check for is a
  // hash that is CORRECT for a moment and then silently rewritten 350 ms
  // later by onRouteChanged()'s Bible-position correction — a single
  // read at the end would miss it in both directions.
  (function () {
    var last = null;
    setInterval(function () {
      try {
        if (location.hash !== last) {
          last = location.hash;
          window.__ysHashLog.push({ t: Date.now(), hash: last });
        }
      } catch (e) { /* ignore */ }
    }, 60);
  })();
`;

// ── browser (one throwaway profile per instance) ─────────────────────

let nextPort = 9500;

class Browser {
  static async launch(label, lang = LANG) {
    const dir = mkdtempSync(join(tmpdir(), 'ys-web-verify-'));
    const port = nextPort++;
    const args = [
      '--headless=new',
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${dir}`,
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      // Deterministic capture size; per-case overrides go through
      // Emulation.setDeviceMetricsOverride.
      '--window-size=1280,900',
      // `--lang` sets Chrome's own UI/Accept-Language locale; `navigator.
      // language` on a fresh profile (no override in chrome://settings,
      // which a throwaway `--user-data-dir` never has) is derived from
      // it, and that is what `AppSettings._detectSystemLocale()`
      // (lib/models/app_settings.dart:1297) reads via
      // `platformDispatcher.locale` on the FIRST boot of a profile with
      // no persisted `locale` pref — exactly this harness's profiles,
      // every run. `--accept-lang` pins the HTTP header the same way so
      // the two can't disagree.
      `--lang=${lang}`,
      `--accept-lang=${lang}`,
    ];
    const proc = spawn(CHROME, args, { stdio: 'ignore' });
    const b = new Browser(proc, dir, port, label);
    for (let i = 0; i < 75; i++) {
      try { await fetch(`http://127.0.0.1:${port}/json/version`); return b; }
      catch { await sleep(200); }
    }
    b.close();
    throw new Error(`Chrome did not come up on port ${port} in 15s`);
  }

  constructor(proc, dir, port, label) {
    this.proc = proc; this.dir = dir; this.port = port; this.label = label;
    this.cdp = null; this.tabId = null;
    this.console = []; this.exceptions = []; this.requests = [];
    this.inflight = new Map();
  }

  async openTab() {
    const tab = await (await fetch(
      `http://127.0.0.1:${this.port}/json/new?about:blank`,
      { method: 'PUT' })).json();
    this.tabId = tab.id;
    this.cdp = new Cdp(tab.webSocketDebuggerUrl);
    await this.cdp.ready;
    this.cdp.on((m, p) => {
      if (m === 'Runtime.consoleAPICalled') {
        this.console.push(`${p.type}: ` + (p.args || [])
          .map((a) => a.value ?? a.description ?? '').join(' '));
      } else if (m === 'Runtime.exceptionThrown') {
        const d = p.exceptionDetails;
        this.exceptions.push(`${d.text} ${d.exception?.description || d.exception?.value || ''}`
          .slice(0, 400));
      } else if (m === 'Network.requestWillBeSent') {
        // Kept only so a loadingFailed can be reported with its URL —
        // a request that never got a response is exactly the shape a
        // CORS or connectivity problem takes, and "(failed) <opaque
        // requestId>" is useless in a report.
        this.inflight.set(p.requestId, p.request?.url || '');
      } else if (m === 'Network.responseReceived') {
        this.requests.push({ url: p.response.url, status: p.response.status });
      } else if (m === 'Network.loadingFailed') {
        this.requests.push({
          url: this.inflight.get(p.requestId) || `(requestId ${p.requestId})`,
          status: 0, error: p.errorText, blocked: p.blockedReason,
        });
      }
    });
    await this.cdp.send('Runtime.enable');
    await this.cdp.send('Page.enable');
    await this.cdp.send('Network.enable');
    await this.cdp.send('Page.addScriptToEvaluateOnNewDocument', { source: INSTRUMENT });
    return this.cdp;
  }

  async metrics({ width, height, dsr = 2, mobile = false }) {
    await this.cdp.send('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: dsr, mobile,
    });
  }

  close() {
    try { this.cdp?.close(); } catch { /* ignore */ }
    try { this.proc.kill(); } catch { /* ignore */ }
    // Node's fs API on a mkdtemp path under the OS temp dir, same as
    // tools/boot_trap_headless_repro.mjs's own cleanup. Each profile is
    // ~40 MB and a full run makes a dozen of them.
    try { rmSync(this.dir, { recursive: true, force: true }); } catch { /* ignore */ }
  }
}

// ── page helpers ─────────────────────────────────────────────────────

async function evalJs(cdp, expression, awaitPromise = false) {
  const r = await cdp.send('Runtime.evaluate', {
    expression, returnByValue: true, awaitPromise,
  });
  if (r.exceptionDetails) {
    throw new Error('page eval threw: ' +
      (r.exceptionDetails.exception?.description || r.exceptionDetails.text));
  }
  return r.result?.value;
}

async function navigate(cdp, url) {
  await cdp.send('Page.navigate', { url });
  for (let i = 0; i < 100; i++) {
    const st = await evalJs(cdp, 'document.readyState').catch(() => null);
    if (st === 'complete') return;
    await sleep(200);
  }
}

/// True once the engine has painted — `<flt-glass-pane>` is the shadow
/// host it creates on its first frame, and is a far better "did it boot"
/// signal than any text read, for the canvas reason in the header.
async function waitForFlutter(cdp, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const ok = await evalJs(cdp,
      `!!document.querySelector('flt-glass-pane')`).catch(() => false);
    if (ok) return true;
    await sleep(250);
  }
  return false;
}

/// Turn on the accessibility tree (see header note (a)). Idempotent —
/// the placeholder removes itself once the engine has switched over.
async function enableSemantics(cdp) {
  return evalJs(cdp, `(function () {
    var p = document.querySelector('flt-semantics-placeholder');
    if (!p) return 'already-on-or-absent';
    p.click();
    return 'clicked';
  })()`);
}

const SEMANTICS_DUMP = `(function () {
  var host = document.querySelector('flt-semantics-host');
  if (!host) {
    var gp = document.querySelector('flt-glass-pane');
    if (gp && gp.shadowRoot) host = gp.shadowRoot.querySelector('flt-semantics-host');
  }
  if (!host) return { ok: false, nodes: [] };
  var out = [];
  var els = host.querySelectorAll('*');
  for (var i = 0; i < els.length; i++) {
    var e = els[i];
    var r = e.getBoundingClientRect();
    var own = '';
    for (var j = 0; j < e.childNodes.length; j++) {
      if (e.childNodes[j].nodeType === 3) own += e.childNodes[j].nodeValue;
    }
    var label = e.getAttribute('aria-label');
    var t = (own || label || '').trim();
    if (!t) continue;
    out.push({
      tag: e.tagName, role: e.getAttribute('role'), text: t,
      x: r.x, y: r.y, w: r.width, h: r.height,
      cx: Math.round(r.x + r.width / 2), cy: Math.round(r.y + r.height / 2),
    });
  }
  return { ok: true, hash: location.hash, nodes: out };
})()`;

async function semantics(cdp) {
  return evalJs(cdp, SEMANTICS_DUMP);
}

/// All visible semantics text, joined — the page-identity oracle.
async function pageText(cdp) {
  const s = await semantics(cdp);
  return (s.nodes || []).map((n) => n.text).join(' │ ');
}

async function waitForText(cdp, re, timeoutMs = 20000) {
  const start = Date.now();
  let last = '';
  while (Date.now() - start < timeoutMs) {
    last = await pageText(cdp).catch(() => '');
    if (re.test(last)) return { found: true, text: last };
    await sleep(300);
  }
  return { found: false, text: last };
}

/// A real click: Flutter's own hit test, at the coordinates the
/// accessibility tree reports for the node whose text matches `re`.
/// `element.click()` is deliberately NOT used — only `role=button`
/// semantics nodes forward a DOM click to the framework, and half the
/// targets here (list rows, posters, chips) are not that.
/// `box` is [x0, y0, x1, y1] in CSS px: only nodes whose centre lies
/// inside it are candidates. It exists because the chronology plot is a
/// horizontally scrolling box — every event label in it is laid out and
/// carries a semantics node even when it is scrolled a thousand pixels
/// off the right of the window, and one of those out-of-frame labels
/// prints the same title as the chip below the chart. Without a box the
/// first match is the invisible one, and the click goes nowhere at all.
///
/// 2026-09-06. `chronology`'s own case had exactly this failure with the
/// box argument unset: an unanchored regex matched the merged event lane
/// (which holds all 64 event titles in ONE semantics node, ahead of the
/// intended chip in tree order) and the "click" landed on a tick instead.
/// It shipped that way and was never caught, because a match was found and
/// something was clicked — there was nothing distinguishing "the only
/// candidate" from "the first of several". So every call is now logged to
/// CLICK_LOG with how many nodes matched; a call site matching more than
/// one is printed with a warning instead of resolved silently by array
/// order. `site` is a free-text label for that log — pass one per call
/// site so results.json reads as "which regex, where" rather than a list
/// of anonymous entries.
async function clickText(cdp, re, { index = 0, timeoutMs = 15000,
    box = null, site = null } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const s = await semantics(cdp);
    const hits = (s.nodes || []).filter(
      (n) => re.test(n.text) && n.w > 0 && n.h > 0 && n.cy > 0 &&
        (!box || (n.cx >= box[0] && n.cy >= box[1] &&
                  n.cx <= box[2] && n.cy <= box[3])));
    if (hits[index]) {
      const n = hits[index];
      for (const type of ['mousePressed', 'mouseReleased']) {
        await cdp.send('Input.dispatchMouseEvent', {
          type, x: n.cx, y: n.cy, button: 'left', clickCount: 1,
        });
        await sleep(40);
      }
      const entry = {
        site: site || re.toString(), regex: re.toString(), box,
        candidates: hits.length, clickedIndex: index,
        matchedText: n.text.slice(0, 160),
        otherTexts: hits.length > 1 ?
          hits.filter((_, i) => i !== index).map((h) => h.text.slice(0, 80)) :
          [],
      };
      CLICK_LOG.push(entry);
      if (hits.length > 1) {
        console.log(`   ⚠ clickText(${entry.site}) matched ${hits.length} ` +
          `nodes, not 1 — clicked hits[${index}]=${JSON.stringify(entry.matchedText)}; ` +
          `others: ${JSON.stringify(entry.otherTexts)}`);
      }
      return { ...n, candidates: hits.length };
    }
    await sleep(300);
  }
  CLICK_LOG.push({
    site: site || re.toString(), regex: re.toString(), box,
    candidates: 0, clickedIndex: index, matchedText: null, notFound: true,
  });
  return null;
}

const TOUR_RE = /Welcome to Yahweh|欢迎使用|歡迎使用|onboard/i;
const SKIP_RE = /^(Skip|跳过|跳過)$/;

/// The first-run tour, dismissed the way a reader would.
///
/// It does NOT open with the page. `OnboardingDialog.shouldShow` awaits
/// `SharedPreferences.getInstance()` first, so the dialog lands a few
/// seconds after the engine paints — a single check right after boot
/// finds nothing and then the tour covers the page you were about to
/// assert on. So: poll for it, click Skip, poll again to confirm it
/// actually went, and record the hash on both sides. The hash either
/// side of a `PopupRoute` opening over a registered route is exactly
/// what main.dart:1261-1269 says once broke.
async function dismissOnboarding(cdp, timeoutMs = 25000) {
  const hashBefore = await evalJs(cdp, 'location.hash').catch(() => null);
  const start = Date.now();
  let appeared = false;
  while (Date.now() - start < timeoutMs) {
    const t = await pageText(cdp).catch(() => '');
    if (TOUR_RE.test(t)) { appeared = true; break; }
    await sleep(500);
  }
  if (!appeared) {
    return { appeared: false, hashBefore,
             hashAfter: await evalJs(cdp, 'location.hash').catch(() => null) };
  }
  const hashDuring = await evalJs(cdp, 'location.hash').catch(() => null);
  const hit = await clickText(cdp, SKIP_RE, { timeoutMs: 10000 });
  let gone = false;
  for (let i = 0; i < 20; i++) {
    await sleep(500);
    const t = await pageText(cdp).catch(() => '');
    if (!TOUR_RE.test(t)) { gone = true; break; }
  }
  return {
    appeared: true, clickedSkip: !!hit, dismissed: gone,
    hashBefore, hashDuring,
    hashAfter: await evalJs(cdp, 'location.hash').catch(() => null),
  };
}

async function screenshot(cdp, name, { fullPage = false } = {}) {
  mkdirSync(OUT_DIR, { recursive: true });
  const params = { format: 'png' };
  if (fullPage) params.captureBeyondViewport = true;
  const r = await cdp.send('Page.captureScreenshot', params);
  const f = join(OUT_DIR, name.endsWith('.png') ? name : name + '.png');
  writeFileSync(f, Buffer.from(r.data, 'base64'));
  return f;
}

async function hashLog(cdp) {
  return evalJs(cdp, 'window.__ysHashLog || []').catch(() => []);
}
async function pageErrors(cdp) {
  return evalJs(cdp, 'window.__ysErrors || []').catch(() => []);
}

/// Boot one case: fresh profile, ONE document load of `url`, wait for the
/// engine, turn on semantics, dismiss the tour. Nothing planted unless
/// `plant` is given (only `sermon` does).
async function coldLoad(label, origin, url,
    { plant = null, viewport = null, semantics: withSemantics = true,
      lang = LANG } = {}) {
  const b = await Browser.launch(label, lang);
  const cdp = await b.openTab();
  if (viewport) await b.metrics(viewport);
  if (plant) {
    // Planting needs an origin document to own the localStorage, so this
    // one case pays for a preliminary load, then bounces through
    // about:blank — a same-origin navigation differing only in the
    // fragment is a SAME-DOCUMENT navigation in Chrome, which would skip
    // main() and therefore captureBootHash() entirely.
    await navigate(cdp, origin + '/');
    await waitForFlutter(cdp, 30000);
    await evalJs(cdp, `(function () {
      localStorage.clear();
      var p = ${JSON.stringify(plant)};
      for (var k in p) localStorage.setItem(k, p[k]);
      return Object.keys(localStorage).sort();
    })()`);
    await navigate(cdp, 'about:blank');
  }
  await navigate(cdp, url);
  const booted = await waitForFlutter(cdp, 40000);
  // The accessibility tree is the harness's only oracle on a canvas app,
  // so it is on by default. It is OPTIONAL because turning it on is not
  // free: Flutter web puts a real DOM overlay over the canvas and every
  // node in it that carries a tap action takes clicks BEFORE the render
  // tree ever hit-tests. A case that needs to know what an ordinary
  // pointer does has to run with it off — see runVersionProbe.
  if (withSemantics) await enableSemantics(cdp);
  await sleep(2500);
  return { b, cdp, booted };
}

// ── case 1: the four owed addresses ──────────────────────────────────

const ROUTE_CASES = [
  {
    hash: '#/settings/ai',
    // The page identity is SettingsPage either way, so page identity is
    // NOT the interesting half here — `settingsSectionForSlug('ai')`
    // reaching `Scrollable.ensureVisible(_aiKey)` is. The state oracle
    // is therefore the AI section's own copy (`aiByokTitle`,
    // `aiModelTitle`), not the string "AI": a case-insensitive /AI/
    // matches "Available", "Main", "Fail" and half of Settings, and an
    // oracle that passes whether or not the feature works is not one.
    wantPage: /Settings|设置|設定/i,
    wantState: /Gemini|AI response depth|AI 响应深度|AI 回應深度/i,
    // 2026-09-03: `wantState` alone is not enough here, and finding that
    // out is what this line is. The semantics tree carries every node the
    // list has BUILT, including ones scrolled off the top — and after the
    // deep-link fix the sections above AI are exactly that. So a text
    // match proves the section exists, not that the reader can see it.
    // `wantVisible` is checked against each node's own
    // `getBoundingClientRect()` instead: the AI header has to sit inside
    // the viewport, which is the whole claim `/settings/:section` makes.
    wantVisible: /^AI$/,
    what: 'SettingsPage, scrolled to the AI section (Gemini key card visible)',
  },
  {
    hash: '#/settings',
    // CONTROL for the case above, not one of the four owed addresses.
    // Bare `/settings` opens at the top of the page by construction
    // (`initialSection` is null, `_keyFor` returns null, nothing
    // scrolls). If this and `/settings/ai` render the SAME visible
    // text, then the `:section` slug did nothing and the difference
    // between the two registrations is only in the address bar.
    wantPage: /Settings|设置|設定/i,
    wantState: /Font Size|Interface Language|ACCOUNT|DISPLAY/i,
    what: 'CONTROL — bare /settings, expected to open at the top',
    control: true,
  },
  {
    hash: '#/library/bookmarks',
    // library_page.dart's tab order is notes=0, bookmarks=1 — the plan's
    // §3 row says so explicitly because it originally had them backwards.
    // Landing on Notes here is a real failure, not a near miss.
    wantPage: /Library|图书馆|圖書館|Notes|Bookmarks|笔记|書籤|书签/i,
    wantState: /Bookmark|书签|書籤/i,
    what: 'LibraryPage on tab 1 (bookmarks), not tab 0 (notes)',
  },
  {
    hash: '#/evidence?book=John&chapter=3',
    wantPage: /Evidence|考古|证据|證據/i,
    wantState: /John|约翰|約翰/i,
    what: 'EvidencePage filtered to John 3 — the query string has to '
      + 'survive the hash, hashToRoutePath, matchesRegisteredRoute and '
      + 'Get.parameters intact',
  },
  {
    hash: '#/songs/cdc%3Ad0180/score',
    // Percent-encoded colon: song ids are `<source>:<slug>`. GetX has to
    // decode it back to `cdc:d0180` for SongScoreByIdPage's lookup.
    wantPage: /Consecrated|Score|乐谱|樂譜|D0180/i,
    wantState: /Consecrated/i,
    // The title alone would pass even with an empty grey viewer, so the
    // absence of `song_score_page.dart`'s own error banner is checked
    // too — that banner is the page saying it could not render.
    wantNot: /could not be loaded|FPDF_ERR|Failed to open document/i,
    what: 'SongScorePage for cdc:d0180 (id percent-encoded in the path), '
      + 'with the PDF actually rendering rather than the error banner',
  },
];

async function runRoutes(origin) {
  console.log('\n════ 1. URL routing — cold load of the four owed addresses ════');
  console.log('Fresh Chrome profile per navigation. Nothing planted: each is');
  console.log('a genuine first visit, which is also why the first-run tour');
  console.log('appears in every one of them.\n');
  const results = [];
  for (const c of ROUTE_CASES) {
    const url = origin + '/' + c.hash;
    console.log(`── ${c.hash}`);
    console.log(`   expecting: ${c.what}`);
    const { b, cdp, booted } = await coldLoad('route', origin, url);
    const r = { hash: c.hash, booted };
    try {
      const hashAtBoot = await evalJs(cdp, 'location.hash');
      const tour = await dismissOnboarding(cdp);
      await sleep(2500);
      const text = await pageText(cdp);
      const sem = await semantics(cdp);
      const viewportH = await evalJs(cdp, 'window.innerHeight');
      const hashAfter = await evalJs(cdp, 'location.hash');
      // Watch a further 4 s: the clobber this item exists to prevent is
      // a 350 ms-delayed rewrite, and a dialog closing re-fires
      // didPop → onRouteChanged.
      await sleep(4000);
      const hashSettled = await evalJs(cdp, 'location.hash');
      const log = await hashLog(cdp);
      const errs = await pageErrors(cdp);

      r.engineBooted = booted;
      r.tour = tour;
      r.hashAtBoot = hashAtBoot;
      r.hashAfterTour = hashAfter;
      r.hashSettled = hashSettled;
      r.hashChanges = log.map((e) => e.hash);
      r.pageOk = c.wantPage.test(text);
      r.stateOk = c.wantState.test(text) && !(c.wantNot && c.wantNot.test(text));
      if (c.wantVisible) {
        const onScreen = (sem.nodes || []).filter((n) =>
          c.wantVisible.test(n.text) && n.h > 0 && n.y >= 0 && n.y < viewportH);
        r.visibleOk = onScreen.length > 0;
        r.visibleAt = onScreen.map((n) => Math.round(n.y));
        r.matchedAnywhere = (sem.nodes || [])
          .filter((n) => c.wantVisible.test(n.text))
          .map((n) => Math.round(n.y));
      }
      // Percent-decode both sides. `#/songs/cdc%3Ad0180/score` comes back
      // as `#/songs/cdc:d0180/score` — GetX re-writes the fragment with
      // the DECODED route name, and a literal colon is legal in a path
      // segment (RFC 3986 §3.3), so the link still names the same song.
      // That is a normalisation, not the Bible-position clobber this
      // check exists to catch, and conflating the two would report a
      // cosmetic difference as the bug.
      const dec = (s) => { try { return decodeURIComponent(s); } catch { return s; } };
      r.hashOk = dec(hashSettled) === dec(c.hash);
      r.hashVerbatim = hashSettled === c.hash;
      r.errors = errs;
      r.text = text.slice(0, 900);
      r.shot = await screenshot(cdp, 'route-' + c.hash.replace(/[^a-z0-9]+/gi, '_'));

      console.log(`   engine painted:        ${booted}`);
      console.log(`   first-run tour opened: ${tour.appeared}` +
        (tour.appeared ? ` (Skip clicked: ${tour.clickedSkip}, gone: ${tour.dismissed})` : ''));
      console.log(`   hash at boot:          ${JSON.stringify(hashAtBoot)}`);
      console.log(`   hash while tour open:  ${JSON.stringify(tour.hashDuring ?? null)}`);
      console.log(`   hash after tour:       ${JSON.stringify(hashAfter)}`);
      console.log(`   hash +4s (settled):    ${JSON.stringify(hashSettled)}  ` +
        `${r.hashOk ? (r.hashVerbatim ? 'SURVIVED verbatim' : 'SURVIVED (percent-decoded by GetX)')
                    : 'CLOBBERED — expected ' + c.hash}`);
      console.log(`   every hash seen:       ${JSON.stringify(r.hashChanges)}`);
      console.log(`   right page:            ${r.pageOk ? 'YES' : 'NO'}  (/${c.wantPage.source}/)`);
      console.log(`   state restored:        ${r.stateOk ? 'YES' : 'NO'}  (/${c.wantState.source}/` +
        (c.wantNot ? ` and NOT /${c.wantNot.source}/` : '') + ')');
      if (c.wantVisible) {
        console.log(`   ON SCREEN:             ${r.visibleOk ? 'YES' : 'NO'}  ` +
          `(/${c.wantVisible.source}/ inside the ${viewportH}px viewport; ` +
          `matched at y=${JSON.stringify(r.matchedAnywhere)}, ` +
          `on-screen at y=${JSON.stringify(r.visibleAt)})`);
      }
      if (errs.length) console.log(`   page errors:           ${JSON.stringify(errs)}`);
      // Off-origin responses, so a page that renders but cannot fetch
      // its own remote content (the CDC score PDF is on
      // christiandiscipleschurch.org, not in the bundle) says so here
      // rather than being read as a routing failure.
      r.offOrigin = b.requests
        .filter((q) => !q.url.startsWith(origin) && !q.url.startsWith('data:'))
        .map((q) => `${q.status} ${q.url.slice(0, 120)}${q.error ? ' err=' + q.error : ''}`);
      if (r.offOrigin.length) {
        console.log(`   off-origin fetches:`);
        for (const q of r.offOrigin.slice(0, 10)) console.log(`     ${q}`);
      }
      console.log(`   semantics text:        ${text.slice(0, 320)}`);
      console.log(`   screenshot:            ${r.shot}`);
    } catch (e) {
      r.error = String(e);
      console.log(`   HARNESS ERROR: ${e.stack || e}`);
    } finally {
      b.close();
    }
    results.push(r);
    console.log('');
  }
  return results;
}

// ── case 2: the original bug — a sermon's address ────────────────────

async function runSermon(origin, { withPlant = true } = {}) {
  if (withPlant) {
    console.log('\n════ 1b. The originally reported bug ════');
    console.log('"Open a sermon and the address bar still reads Micah 2:1."');
    console.log('Micah 2 is PLANTED in localStorage first (the same three');
    console.log('shared_preferences keys tools/boot_trap_headless_repro.mjs');
    console.log('plants, JSON-encoded the way shared_preferences_web writes');
    console.log('them) so MainProvider restores a Bible position that is');
    console.log('unmistakably not the sermon. Then: cold-load /#/sermons,');
    console.log('open sermon 004, and watch the fragment for 8 s — the bug is');
    console.log('a 350 ms-delayed rewrite, so a single read would miss it.\n');
  } else {
    console.log('\n════ 1c. Back / Forward CONTROL — nothing planted ════');
    console.log('Same walk, but no preliminary load and no planted keys, so');
    console.log('the history stack contains only what the app itself put');
    console.log('there. If Back behaves the same way here, the 1b result is');
    console.log('the app, not this harness\'s two-step planting setup.\n');
  }

  const plant = withPlant ? {
    'flutter.book': JSON.stringify('Micah'),
    'flutter.chapter': JSON.stringify(2),
    'flutter.version': JSON.stringify('kjv'),
  } : null;
  const { b, cdp, booted } = await coldLoad(
    withPlant ? 'sermon' : 'sermon-control', origin,
    origin + '/#/sermons', { plant });
  const out = { booted };
  try {
    await dismissOnboarding(cdp);
    await sleep(1500);
    const listText = await pageText(cdp);
    const hashOnList = await evalJs(cdp, 'location.hash');
    console.log(`   /#/sermons loaded, hash: ${JSON.stringify(hashOnList)}`);
    console.log(`   list text: ${listText.slice(0, 260)}`);

    // Snapshot the history stack BEFORE the in-app push. Whether opening
    // a sermon ADDS a browser history entry or merely rewrites the
    // current one is the whole question for Back, and it is only
    // answerable by comparing the two — docs/url-routing-plan.md §5
    // assumes a new entry per navigation ("each pushPage navigation
    // still creates a browser history entry").
    const histBefore = await cdp.send('Page.getNavigationHistory');
    out.historyBefore = {
      count: histBefore.entries.length,
      index: histBefore.currentIndex,
      urls: histBefore.entries.map((e) => e.url.replace(origin, '')),
    };

    // The list opens grouped by topic with every group collapsed, so
    // no sermon title is on screen yet — expand "Baptism" first, which
    // is where sermon 004 ("Temptation After Baptism…") lives per
    // assets/sermons/index.json.
    const topic = await clickText(cdp, /^Baptism\b/i,
      { timeoutMs: 20000, site: 'runSermon:expandTopic' });
    console.log(`   expanded topic: ${topic ? JSON.stringify(topic.text.slice(0, 60)) : 'NOT FOUND'}`);
    await sleep(2000);
    // Unanchored and unboxed on purpose, not by oversight — see the
    // 2026-09-06 sweep this comment documents. `SermonLibraryPage`'s own
    // comment (that file, :28-38) records the reason a collapsed
    // ExpansionTile's rows are safe to leave unanchored: Flutter never
    // BUILDS the children of a collapsed tile, so the OTHER sermon whose
    // title also contains "Temptation" ("Woe to the Man by Whom
    // Temptation Comes…", assets/sermons/index.json:929) has no semantics
    // node to match while its own topic group sits collapsed. `candidates`
    // is asserted below anyway rather than trusted from that reasoning
    // alone — a future change that auto-expands more than one group would
    // make the premise false without touching this file.
    const hit = await clickText(cdp, /Temptation/i,
      { timeoutMs: 20000, site: 'runSermon:sermonRow' });
    console.log(`   clicked a sermon row: ${hit ? JSON.stringify(hit.text.slice(0, 80)) : 'NOT FOUND'}`);
    out.openedRow = hit ? hit.text.slice(0, 120) : null;
    out.openedRowCandidates = hit ? hit.candidates : 0;
    // The failure mode this guards: the group's OWN header ("Baptism\n12
    // sermon(s)") also matches nothing here, but if it ever did — or if a
    // second group were open — clicking hits[0] could re-collapse the
    // topic instead of opening a sermon, and `out.openedRow` would still
    // hold text that LOOKS like a success. Comparing against the topic
    // header's own text, and against the expected title, is what makes
    // that distinguishable instead of decorative.
    out.openedRowIsGroupHeader = !!(hit && topic && hit.text === topic.text);
    out.openedRowIsExpectedSermon =
      !!(hit && /Temptation After Baptism/i.test(hit.text));
    if (out.openedRowCandidates > 1) {
      console.log(`   sermon-row click was AMBIGUOUS: ${out.openedRowCandidates} candidates matched /Temptation/i`);
    }
    if (out.openedRowIsGroupHeader) {
      console.log('   the click landed on the TOPIC HEADER, not a sermon row');
    } else if (!out.openedRowIsExpectedSermon) {
      console.log(`   the click landed on neither the expected sermon title nor the header: ${JSON.stringify(out.openedRow)}`);
    }
    await sleep(3000);
    const hashAfterOpen = await evalJs(cdp, 'location.hash');
    const detailText = await pageText(cdp);
    await sleep(8000);
    const hashSettled = await evalJs(cdp, 'location.hash');
    const log = await hashLog(cdp);

    out.hashOnList = hashOnList;
    out.hashAfterOpen = hashAfterOpen;
    out.hashSettled = hashSettled;
    out.hashChanges = log.map((e) => e.hash);
    out.namesSermon = /^#\/sermons\/[^/]+$/.test(hashSettled);
    out.namesBible = /micah|mic\//i.test(hashSettled);
    out.everWentBible = log.some((e) => /micah|mic\//i.test(e.hash));
    out.detailText = detailText.slice(0, 400);
    const tag = withPlant ? 'sermon' : 'sermon-control';
    out.shot = await screenshot(cdp, tag + '-address-bar');

    console.log(`   hash right after open:  ${JSON.stringify(hashAfterOpen)}`);
    console.log(`   hash +8s (settled):     ${JSON.stringify(hashSettled)}`);
    console.log(`   names the sermon:       ${out.namesSermon ? 'YES' : 'NO'}`);
    console.log(`   names a Bible ref:      ${out.namesBible ? 'YES — BUG' : 'no'}`);
    console.log(`   ever showed Micah:      ${out.everWentBible ? 'YES — BUG' : 'no'}`);
    console.log(`   every hash seen:        ${JSON.stringify(out.hashChanges)}`);
    console.log(`   detail page text:       ${detailText.slice(0, 260)}`);
    console.log(`   screenshot:             ${out.shot}`);

    // ── Back / Forward, driven as real history navigation ──
    //
    // Page.navigateToHistoryEntry is the Back BUTTON, not history.back()
    // from script — the distinction matters because the whole mechanism
    // under test is a `popstate` listener, and this is the path the
    // browser chrome itself takes.
    console.log('\n   ── browser Back / Forward ──');
    const h0 = await cdp.send('Page.getNavigationHistory');
    out.historyAfterOpen = {
      count: h0.entries.length, index: h0.currentIndex,
      urls: h0.entries.map((e) => e.url.replace(origin, '')),
    };
    out.pushAddedEntry = h0.entries.length > out.historyBefore.count;
    console.log(`   history BEFORE opening the sermon: ${out.historyBefore.count} entries, ` +
      `index ${out.historyBefore.index}`);
    console.log(`     ${out.historyBefore.urls.map((u, i) =>
      `${i}${i === out.historyBefore.index ? '*' : ' '} ${u}`).join('\n     ')}`);
    console.log(`   history AFTER opening the sermon:  ${h0.entries.length} entries, ` +
      `index ${h0.currentIndex}`);
    console.log(`     ${out.historyAfterOpen.urls.map((u, i) =>
      `${i}${i === h0.currentIndex ? '*' : ' '} ${u}`).join('\n     ')}`);
    console.log(`   opening the sermon added a history entry: ` +
      `${out.pushAddedEntry ? 'YES' : 'NO — the current entry was REWRITTEN in place'}`);

    const backTo = h0.entries[h0.currentIndex - 1];
    if (backTo) {
      await cdp.send('Page.navigateToHistoryEntry', { entryId: backTo.id });
      // Two reads on purpose. The FIRST is before the state→URL writer
      // has had its 150 ms debounce + the route-change correction's
      // 350 ms; the SECOND is after. `_writeStateToUrl` ends in
      // `history.pushState`, and a pushState from anywhere but the tip
      // of the stack DISCARDS every forward entry — so whether Forward
      // still exists depends entirely on which of these two you look at.
      // Sampled, not read once. Back lands, the app reacts, and the
      // reaction is itself several steps (popstate -> _popRouteCallback
      // -> Get.back(), then the 150 ms MainProvider debounce, then the
      // 350 ms route-change correction), so a single late read cannot
      // tell "Back went one step and then something else moved it" from
      // "Back went several steps at once".
      out.backTrace = [];
      let prev = 0;
      for (const at of [40, 150, 600, 1500, 3000]) {
        await sleep(at - prev); prev = at;
        const h = await cdp.send('Page.getNavigationHistory');
        out.backTrace.push({
          at,
          entries: h.entries.length,
          index: h.currentIndex,
          forward: h.entries.length - 1 - h.currentIndex,
          tipUrl: (h.entries[h.entries.length - 1]?.url || '').replace(origin, ''),
          hash: await evalJs(cdp, 'location.hash').catch(() => null),
          text: (await pageText(cdp).catch(() => '')).slice(0, 120),
        });
      }
      for (const t of out.backTrace) {
        console.log(`   BACK  -> +${String(t.at).padStart(4)}ms  ` +
          `entries=${t.entries} index=${t.index} forward=${t.forward}  ` +
          `tip=${JSON.stringify(t.tipUrl)}  hash=${JSON.stringify(t.hash)}`);
        console.log(`                    page="${t.text.replace(/\n/g, ' ').slice(0, 88)}"`);
      }
      out.hashImmediatelyAfterBack = out.backTrace[0].hash;
      out.forwardEntriesImmediatelyAfterBack = out.backTrace[0].forward;

      await sleep(2000);
      out.hashAfterBack = await evalJs(cdp, 'location.hash');
      out.textAfterBack = (await pageText(cdp)).slice(0, 300);
      const h1 = await cdp.send('Page.getNavigationHistory');
      out.forwardEntriesAfterSettling = h1.entries.length - 1 - h1.currentIndex;
      console.log(`            +5s   hash ${JSON.stringify(out.hashAfterBack)}, ` +
        `${out.forwardEntriesAfterSettling} forward entr(y/ies) available`);
      console.log(`            page ${out.textAfterBack.slice(0, 200)}`);
      out.backLeftDetail = !/^#\/sermons\/[^/]+$/.test(out.hashAfterBack || '');
      out.backShowsList = /289 sermons|sermon\(s\)|Search sermons/i.test(out.textAfterBack || '');
      console.log(`            left the detail page:  ${out.backLeftDetail}`);
      console.log(`            shows the sermon LIST: ${out.backShowsList}` +
        (out.backShowsList ? '' : '  <-- Back did not unwind to /#/sermons'));
      out.shotBack = await screenshot(cdp, tag + '-after-back');

      const fwdTo = h1.entries[h1.currentIndex + 1];
      if (fwdTo) {
        await cdp.send('Page.navigateToHistoryEntry', { entryId: fwdTo.id });
        await sleep(4000);
        out.hashAfterForward = await evalJs(cdp, 'location.hash');
        out.textAfterForward = (await pageText(cdp)).slice(0, 300);
        console.log(`   FWD   -> hash ${JSON.stringify(out.hashAfterForward)}`);
        console.log(`            page ${out.textAfterForward.slice(0, 200)}`);
        out.forwardRestoredDetail =
          /^#\/sermons\/[^/]+$/.test(out.hashAfterForward || '');
        console.log(`            back on the sermon: ${out.forwardRestoredDetail}`);
        out.shotForward = await screenshot(cdp, tag + '-after-forward');
      } else {
        out.forwardRestoredDetail = false;
        out.forwardGone = true;
        console.log('   FWD   -> NO FORWARD ENTRY EXISTS — the stack was ' +
          'truncated after Back, so Forward is unreachable from the browser UI');
      }
    } else {
      console.log('   BACK  -> no previous entry exists');
    }
    out.finalHashLog = (await hashLog(cdp)).map((e) => e.hash);
    console.log(`   full hash trace: ${JSON.stringify(out.finalHashLog)}`);
    out.historyCalls = await evalJs(cdp, 'window.__ysHistory || []').catch(() => []);
    const t0 = out.historyCalls[0]?.t ?? 0;
    console.log('   every History API call and popstate, in order:');
    for (const h of out.historyCalls) {
      console.log(`     +${String(h.t - t0).padStart(6)}ms  ${h.op.padEnd(12)} ` +
        `${(h.url || '').padEnd(24)} state=${h.state}`);
    }
  } catch (e) {
    out.error = String(e);
    console.log(`   HARNESS ERROR: ${e.stack || e}`);
  } finally {
    b.close();
  }
  return out;
}

// ── case 3: the YouTube handshake ────────────────────────────────────

async function runYoutube(origin, { lang = LANG } = {}) {
  console.log('\n════ 2. YouTube language-switch handshake ════');
  console.log(`profile locale: --lang=${lang}`);
  console.log('Claim under test (youtube_embed_web.dart + _src.dart):');
  console.log('  (i)   the iframe src carries enablejsapi=1 and origin');
  console.log('  (ii)  the page posts `listening` on load and 10x at 500ms');
  console.log('  (iii) the player answers with frames carrying currentTime');
  console.log('  (iv)  a language switch re-mounts the embed with ?start=N');
  console.log('(i), (ii) and (iv) are observable regardless of network.');
  console.log('(iii) needs youtube-nocookie.com to actually answer from');
  console.log('this machine — reported separately, never merged with (i).\n');

  const { b, cdp, booted } = await coldLoad(
    'youtube', origin, origin + '/#/videos/cross', { lang });
  const out = { booted, lang };
  try {
    await dismissOnboarding(cdp);
    await sleep(2000);
    console.log(`   /#/videos/cross text: ${(await pageText(cdp)).slice(0, 260)}`);

    // The embed only mounts after a tap — videos_page.dart:592's poster
    // InkWell, which is bare (an Icon + a conditional caption, no
    // semantics text of its own — checked at videos_page.dart:636-656).
    // So this was never really "clicking the poster": under English it
    // matched the AppBar TITLE above the poster (`s.titleFor(locale)`,
    // videos_page.dart:362), a harmless no-op tap, and the actual mount
    // has always come from the raw-coordinate fallback below. 2026-09-06
    // sweep originally attributed the "中文" collision risk to THIS regex;
    // that was wrong — "中文" belongs to `videoLangChinese`
    // (ui_strings.dart:6119), the whole-series compilation button
    // (`_wholeSeriesRow`, videos_page.dart:466-481), which this regex
    // never touches, and it is the OTHER click below (`languageChip`)
    // that collided with it. What IS true of this regex, confirmed by a
    // real zh-Hans run (see queue :12687 and results.json), is that
    // `播放` / `第1集` / `Episode 1` are not this app's strings anywhere,
    // so at zh-Hans/zh-Hant the only candidate — the AppBar title
    // "Standing at the Cross" — stops matching and NOTHING MATCHED,
    // relying entirely on the fallback to actually start the video.
    // Anchored here to the title in all three scripts instead, boxed to
    // the AppBar's height so a coincidental match lower on the page
    // (there is none today) could never win by tree order.
    const poster = await clickText(cdp, /Standing at the Cross|在十字架下/i,
      { timeoutMs: 12000, box: [0, 0, 1280, 72], site: 'runYoutube:poster' });
    console.log(`   tapped: ${poster ? JSON.stringify(poster.text.slice(0, 70)) : 'NOTHING MATCHED'}`);
    if (poster && poster.candidates > 1) {
      console.log(`   poster click was AMBIGUOUS: ${poster.candidates} nodes matched — this is a single-video page (/#/videos/cross), so a second match is worth reading in results.json before trusting the tap`);
    }
    out.posterCandidates = poster ? poster.candidates : 0;
    await sleep(3000);
    let frames = await evalJs(cdp, IFRAME_DUMP);
    if (!frames.length) {
      // Fall back to a raw click in the top-middle of the page, where the
      // 16:9 poster sits, in case the poster carries no semantics label.
      console.log('   no iframe yet — clicking the poster area directly');
      for (const type of ['mousePressed', 'mouseReleased']) {
        await cdp.send('Input.dispatchMouseEvent',
          { type, x: 640, y: 260, button: 'left', clickCount: 1 });
        await sleep(50);
      }
      await sleep(3000);
      frames = await evalJs(cdp, IFRAME_DUMP);
    }
    out.iframes = frames;
    console.log(`   iframes in the document: ${frames.length}`);
    for (const f of frames) console.log(`     src = ${f.src}`);

    const src = frames[0]?.src || '';
    out.srcHasJsApi = /[?&]enablejsapi=1(&|$)/.test(src);
    out.srcHasOrigin = /[?&]origin=/.test(src);
    out.srcHost = /^https:\/\/www\.youtube-nocookie\.com\//.test(src);
    console.log(`   (i) enablejsapi=1 present: ${out.srcHasJsApi}`);
    console.log(`       origin= present:       ${out.srcHasOrigin}`);
    console.log(`       nocookie host:         ${out.srcHost}`);

    // Let the 10 pokes at 500 ms run out, plus room for a reply.
    await sleep(9000);
    out.posted = await evalJs(cdp, 'window.__ysOut || []');
    out.received = await evalJs(cdp, 'window.__ysIn || []');
    const listening = out.posted.filter((p) => /"event"\s*:\s*"listening"/.test(p.msg));
    out.listeningCount = listening.length;
    console.log(`   (ii) postMessage() calls into the iframe: ${out.posted.length}`);
    console.log(`        of which "listening": ${listening.length}`);
    if (listening[0]) {
      console.log(`        payload: ${listening[0].msg}`);
      console.log(`        targetOrigin: ${listening[0].target}`);
      const times = listening.map((l) => l.t);
      const gaps = times.slice(1).map((t, i) => t - times[i]);
      out.gaps = gaps;
      console.log(`        gaps between pokes (ms): ${JSON.stringify(gaps)}`);
    }

    const fromPlayer = out.received.filter(
      (m) => /youtube(-nocookie)?\.com$/.test(new URL(m.origin || 'http://x/').host || ''));
    const withTime = out.received.filter((m) => /currentTime/.test(m.data || ''));
    out.playerReplies = fromPlayer.length;
    out.currentTimeFrames = withTime.length;
    console.log(`   (iii) messages received from a youtube origin: ${fromPlayer.length}`);
    console.log(`         of which carry currentTime: ${withTime.length}`);
    if (withTime[0]) console.log(`         first: ${withTime[0].data.slice(0, 240)}`);

    // Did the machine reach YouTube at all? This is what separates
    // "the feature is broken" from "this box has no route to youtube".
    const ytReq = b.requests.filter((r) => /youtube|ytimg|googlevideo/.test(r.url));
    out.youtubeRequests = ytReq.slice(0, 12);
    out.youtubeReachable = ytReq.some((r) => r.status >= 200 && r.status < 400);
    console.log(`   network: ${ytReq.length} youtube-ish responses, ` +
      `reachable = ${out.youtubeReachable}`);
    for (const r of ytReq.slice(0, 8)) {
      console.log(`     ${r.status} ${r.url.slice(0, 110)}${r.error ? ' err=' + r.error : ''}`);
    }

    out.shotBefore = await screenshot(cdp, 'youtube-before-switch');

    // (iv) the language switch.
    //
    // 2026-09-06 sweep: on THIS route (/#/videos/cross, episode 1 of
    // 在十字架下) this regex matches 2 nodes, not 1, and that is correct —
    // `videos_page.dart:673` (`_languageRow`) builds one ChoiceChip per
    // `playableTracks` entry, this is the one episode with all three
    // (en/yue/cmn per that file's own comment at :663-667), and the
    // active language's chip ("English") is excluded from the regex on
    // purpose, so both remaining chips are legitimate, visible, clickable
    // matches — not an off-screen decoy outranking the real target the
    // way the chronology bug's lane did. Every assertion below
    // (`remounted`, `startParam`) only cares THAT a switch happened, not
    // which language was picked, so this is left unboxed and unanchored;
    // `candidates` is still recorded so an assertion that DOES care which
    // language fired can see the ambiguity instead of assuming one.
    //
    // This regex used to also carry `中文` and `國語`. `中文` is
    // `videoLangChinese` (ui_strings.dart:6119) — the label on
    // `_wholeSeriesRow`'s whole-series compilation button
    // (videos_page.dart:466-481), a DIFFERENT widget on this same page
    // whose `onPressed` is `LinkOpener.openOrWarn`, i.e. leaves the app
    // for youtube.com — not a wrong-track click but an exit from the
    // page. `_languageRow` builds before `_wholeSeriesRow`
    // (videos_page.dart:394 vs :424), so `hits[0]` order likely favoured
    // the real chip when both matched, but that is inference, not
    // something this file had a run to back up, and it was moot at
    // zh-Hans regardless: the OLD regex carried Traditional `廣東話` but
    // no Simplified `广东话`, so at zh-Hans (chips 英语/广东话/普通话) the
    // Cantonese chip never matched at all and the two remaining
    // candidates were {普通话 chip, 中文 button} — order-dependent, not
    // safe. `國語` was never a string this app uses anywhere (checked);
    // dropped as dead weight, not as part of the fix. Rebuilt from the
    // six real chip strings (oneGodLangYue/Cmn at both scripts) plus
    // their English text, and nothing else, so `中文` is no longer a
    // candidate in any script and tree order stops mattering. See the
    // 2026-09-06 en / zh-Hans run results recorded at queue :12687 for
    // what this actually clicked, in both scripts.
    console.log('\n   ── language switch ──');
    const chip = await clickText(cdp, /Cantonese|Mandarin|广东话|廣東話|普通话|普通話/i,
      { timeoutMs: 10000, site: 'runYoutube:languageChip' });
    console.log(`   tapped language chip: ${chip ? JSON.stringify(chip.text) : 'NOTHING MATCHED'}`);
    if (chip && chip.candidates > 1) {
      console.log(`   language-chip click matched ${chip.candidates} chips (expected — see comment above), clicked "${chip.text}"`);
    }
    out.languageChipCandidates = chip ? chip.candidates : 0;
    await sleep(4000);
    const after = await evalJs(cdp, IFRAME_DUMP);
    out.iframesAfter = after;
    console.log(`   iframes after the switch: ${after.length}`);
    for (const f of after) console.log(`     src = ${f.src}`);
    const newSrc = after[0]?.src || '';
    out.remounted = !!newSrc && newSrc !== src;
    out.startParam = (/[?&]start=(\d+)/.exec(newSrc) || [])[1] ?? null;
    console.log(`   (iv) embed re-mounted: ${out.remounted}`);
    console.log(`        ?start= on the new src: ${out.startParam ?? '(absent)'}`);
    out.shotAfter = await screenshot(cdp, 'youtube-after-switch');
    out.errors = await pageErrors(cdp);
    if (out.errors.length) console.log(`   page errors: ${JSON.stringify(out.errors)}`);
  } catch (e) {
    out.error = String(e);
    console.log(`   HARNESS ERROR: ${e.stack || e}`);
  } finally {
    b.close();
  }
  return out;
}

/// Every <iframe> in the document, shadow roots included — Flutter puts
/// platform views under its own custom elements and the tree moves
/// between engine versions, so this walks rather than assuming a path.
const IFRAME_DUMP = `(function () {
  var out = [];
  function walk(root, depth) {
    if (depth > 12) return;
    var els = root.querySelectorAll('*');
    for (var i = 0; i < els.length; i++) {
      var e = els[i];
      if (e.tagName === 'IFRAME') {
        var r = e.getBoundingClientRect();
        out.push({ src: e.getAttribute('src'), allow: e.getAttribute('allow'),
                   w: Math.round(r.width), h: Math.round(r.height) });
      }
      if (e.shadowRoot) walk(e.shadowRoot, depth + 1);
    }
  }
  walk(document, 0);
  return out;
})()`;

// ── case 4: sermon typography at phone width ─────────────────────────

async function runTypography(origin) {
  console.log('\n════ 3. Sermon paragraph typography at 402 pt ════');
  console.log('_SermonBody: gap 22.0 -> fontSize*0.3 (6.0 at the default 20),');
  console.log('every paragraph indented 2 em, line height 1.75 and the line');
  console.log('measure unchanged. Note the measure is fontSize*34 = 680 pt for');
  console.log('English, so at 402 pt wide the SCREEN is the measure and that');
  console.log('lever is not what is on trial here — the gap and the indent are.');
  console.log('Rendering sermon 004 at 402x874 and capturing it.\n');

  const { b, cdp, booted } = await coldLoad(
    'typo', origin, origin + '/#/sermons/004',
    { viewport: { width: 402, height: 874, dsr: 3, mobile: true } });
  const out = { booted };
  try {
    await dismissOnboarding(cdp);
    await sleep(2500);
    const t = await pageText(cdp);
    out.text = t.slice(0, 500);
    out.onDetail = /Temptation|Baptism|1979/i.test(t);
    console.log(`   page: ${t.slice(0, 260)}`);
    console.log(`   on the sermon detail page: ${out.onDetail}`);
    out.hash = await evalJs(cdp, 'location.hash');
    console.log(`   hash: ${JSON.stringify(out.hash)}`);
    out.shots = [];
    out.shots.push(await screenshot(cdp, 'typography-402-top'));

    // Scroll into the body proper, past the title/credit/chip block, and
    // take three more so a paragraph BOUNDARY is definitely in frame.
    for (let i = 1; i <= 3; i++) {
      await cdp.send('Input.dispatchMouseEvent', {
        type: 'mouseWheel', x: 200, y: 500, deltaX: 0, deltaY: 700,
      });
      await sleep(1200);
      out.shots.push(await screenshot(cdp, `typography-402-scroll${i}`));
    }

    // A number to put next to the picture. Each body paragraph is one
    // `SelectableText.rich` inside a `Padding(bottom: paragraphGap)`, and
    // each becomes one semantics node, so the vertical distance from one
    // paragraph's bottom to the next one's top IS `paragraphGap` — read
    // off the running app rather than off the source. Flutter's logical
    // pixels are CSS pixels here, so these come out in the same pt the
    // code is written in. Expected 6.0 at the default 20 pt font;
    // anything near 22 would mean the old constant is still in effect.
    out.paragraphGaps = await evalJs(cdp, `(function () {
      var host = document.querySelector('flt-semantics-host');
      if (!host) return { err: 'no semantics host' };
      // A \`SelectableText\` is mirrored into the accessibility tree as an
      // \`<flt-semantics>\` wrapping a real \`<textarea>\` (that is how the
      // engine gives a screen reader a selection to move through), and the
      // prose lives in the textarea's VALUE — not in a text child and not
      // in aria-label. Reading either of those measured nothing at all on
      // the first two attempts; this reads the value.
      var boxes = [];
      var areas = host.querySelectorAll('textarea');
      for (var i = 0; i < areas.length; i++) {
        var a = areas[i];
        // The engine leaves this textarea's value EMPTY (checked — the
        // prose is painted to canvas and never mirrored as text), so the
        // paragraph cannot be identified by its words. It can be
        // identified structurally: on this page the only textareas are
        // the body's SelectableTexts, one per paragraph. Geometry is all
        // this measurement needs anyway.
        var wrap = a.closest('flt-semantics') || a;
        var r = wrap.getBoundingClientRect();
        if (r.height < 20) continue;            // not a real paragraph box
        boxes.push({ top: Math.round(r.top * 100) / 100,
                     bottom: Math.round(r.bottom * 100) / 100,
                     height: Math.round(r.height * 100) / 100,
                     head: '(textarea, value not mirrored)' });
      }
      boxes.sort(function (a, b) { return a.top - b.top; });
      var gaps = [];
      for (var k = 1; k < boxes.length; k++) {
        gaps.push({
          gap: Math.round((boxes[k].top - boxes[k - 1].bottom) * 100) / 100,
          after: boxes[k - 1].head,
        });
      }
      return { paragraphs: boxes.length, gaps: gaps, boxes: boxes,
               fontSize: 20, expectedGap: 6.0 };
    })()`);
    console.log(`   paragraph boxes measured: ${out.paragraphGaps.paragraphs ?? 0}`);
    for (const bx of (out.paragraphGaps.boxes || [])) {
      console.log(`     paragraph box top=${bx.top} bottom=${bx.bottom} height=${bx.height}`);
    }
    for (const g of (out.paragraphGaps.gaps || [])) {
      console.log(`     gap ${String(g.gap).padStart(6)} pt   ` +
        `(expected 6.0 = fontSize*0.3; the old constant was 22.0)`);
    }

    // The same sermon at desktop width, as the control: this is where
    // the untouched `measure` lever (fontSize*34 = 680 pt) actually
    // binds, so the two shots together show the change in the only two
    // regimes it has.
    await b.metrics({ width: 1280, height: 900, dsr: 2, mobile: false });
    await sleep(2500);
    out.shots.push(await screenshot(cdp, 'typography-1280-control'));
  } catch (e) {
    out.error = String(e);
    console.log(`   HARNESS ERROR: ${e.stack || e}`);
  } finally {
    b.close();
  }
  for (const s of out.shots || []) console.log(`   screenshot: ${s}`);
  return out;
}

// ── case 6: the Bible reader's own browser history ───────────────────
//
// 2026-09-05. `history`/`sermon` above never touches the Bible reader,
// and the reader is the ONE page whose URL is not written by GetX at
// all: `url_sync_service_web.dart`'s `_writeStateToUrl` calls
// `window.history.pushState` directly, on a 150 ms debounce, for a
// history entry the Flutter engine believes it owns.
//
// docs/autonomous-queue.md's second web-history item says that a Back
// onto one of those entries lands in `SingleEntryBrowserHistory.
// onPopState`'s THIRD branch (the state is neither the `origin` nor the
// `flutter` marker, because our raw pushState wrote `null`), which does
// `go(-1)` and eventually dispatches **`pushRoute`** — i.e. Back grows
// the Navigator stack instead of unwinding it. That claim had never
// been watched happen. This case watches it.
//
// The instrument is the browser's own numbers, not a probe:
//
//   * `Page.getNavigationHistory` before and after an in-app chapter
//     change answers "does reading the next chapter add a browser
//     entry?" — the sermon case's `pushAddedEntry`, asked of the one
//     code path that really does push.
//   * ONE Back, sampled at 40/150/600/1500/3000/5000 ms. A `go(-1)`
//     cascade shows up as `currentIndex` falling by more than one and
//     `forward` rising by the same amount; a `pushRoute` that lands
//     afterwards shows up as those forward entries being TRUNCATED
//     again ~350 ms later, when the route-change correction fires its
//     own pushState from a non-tip entry.
//   * `window.__ysHistory` counts the popstate events one Back
//     produced. One Back that produces one popstate is a pop; one Back
//     that produces three is a cascade.
async function runBible(origin) {
  console.log('\n════ 6. The Bible reader\'s browser history ════');
  console.log('Cold-load a Bible deep link, read two chapters forward with');
  console.log('the in-app Next-chapter control, then press Back ONCE.');
  console.log('`_writeStateToUrl` pushState()s a null-state entry per');
  console.log('chapter; the engine owns the entry underneath them.\n');

  const { b, cdp, booted } = await coldLoad(
    'bible', origin, origin + '/#/micah/2?v=kjv');
  const out = { booted };
  try {
    // The tour has to be GONE, not merely clicked at, before this case
    // can do anything — measured 2026-09-05, the first run of it: one
    // Skip click left the dialog up on this page, and the tour's own
    // "Next" button then swallowed both of the Next-CHAPTER clicks
    // below, so the walk silently measured nothing. `dismissOnboarding`
    // reports `dismissed`; believe it and retry rather than assuming.
    let tour = await dismissOnboarding(cdp);
    for (let i = 0; i < 6 && tour.appeared && !tour.dismissed; i++) {
      await sleep(1200);
      await clickText(cdp, SKIP_RE, { timeoutMs: 6000 });
      await sleep(1500);
      const t = await pageText(cdp).catch(() => '');
      tour = { ...tour, dismissed: !TOUR_RE.test(t), retries: i + 1 };
    }
    out.tour = tour;
    if (tour.appeared && !tour.dismissed) {
      throw new Error('the first-run tour would not dismiss — every click ' +
        'below would land on the dialog, not the page');
    }
    await sleep(2500);
    out.hashOnArrival = await evalJs(cdp, 'location.hash');
    out.textOnArrival = (await pageText(cdp)).slice(0, 300);
    console.log(`   arrived, hash: ${JSON.stringify(out.hashOnArrival)}`);
    console.log(`   page: ${out.textOnArrival.slice(0, 200)}`);

    const hb = await cdp.send('Page.getNavigationHistory');
    out.historyBefore = {
      count: hb.entries.length, index: hb.currentIndex,
      urls: hb.entries.map((e) => e.url.replace(origin, '')),
    };
    console.log(`   history on arrival: ${hb.entries.length} entries, ` +
      `index ${hb.currentIndex}`);
    console.log(`     ${out.historyBefore.urls.map((u, i) =>
      `${i}${i === hb.currentIndex ? '*' : ' '} ${u}`).join('\n     ')}`);

    // Two in-app chapter advances. The control is the bottom bar's
    // chevron, whose tooltip becomes its semantics label — see
    // bible_reading_pane.dart's `_BottomBarBtn(icon: chevron_right)`.
    out.chapterSteps = [];
    let lastHash = out.hashOnArrival;
    for (let i = 0; i < 2; i++) {
      // The label is the button's TOOLTIP, and the tooltip reads
      // "Next Chapter" (title case, one space) — not the `nextChapter`
      // ui_strings value "Next" that bible_reading_pane.dart passes as
      // the fallback. Read off the live semantics tree, not the source.
      // `box` pins the click to the bottom bar as well: the onboarding
      // dialog's own button is labelled "Next" and sits mid-screen, and
      // a looser match picked that one on the first run of this case.
      const hit = await clickText(cdp, /^(next chapter|下一章)$/i,
        { timeoutMs: 15000, box: [0, 640, 1280, 900] });
      if (!hit) {
        // Print what IS on screen rather than leaving "NOT FOUND". A
        // canvas app gives no other way to see why a selector missed.
        const s = await semantics(cdp).catch(() => ({ nodes: [] }));
        console.log('   Next-chapter control not found. Semantics nodes:');
        for (const n of (s.nodes || []).slice(0, 60)) {
          console.log(`     [${n.role || '-'}] y=${Math.round(n.y)} ` +
            `x=${Math.round(n.x)} ${JSON.stringify(n.text.slice(0, 50))}`);
        }
      }
      await sleep(2500);
      const h = await evalJs(cdp, 'location.hash');
      const nh = await cdp.send('Page.getNavigationHistory');
      out.chapterSteps.push({
        clicked: hit ? hit.text : null, hash: h, hashChanged: h !== lastHash,
        entries: nh.entries.length, index: nh.currentIndex,
      });
      console.log(`   Next chapter #${i + 1}: clicked=${JSON.stringify(hit?.text ?? null)} ` +
        `hash=${JSON.stringify(h)} changed=${h !== lastHash} ` +
        `entries=${nh.entries.length} index=${nh.currentIndex}`);
      lastHash = h;
    }
    // Every step must have found a control AND moved the address bar.
    // "The click landed somewhere" is not the same claim as "the reader
    // advanced a chapter", and only the second one makes the Back below
    // mean anything.
    out.chapterNavWorked = out.chapterSteps.every(
      (s) => s.clicked !== null && s.hashChanged);

    const h0 = await cdp.send('Page.getNavigationHistory');
    out.historyAfterReading = {
      count: h0.entries.length, index: h0.currentIndex,
      urls: h0.entries.map((e) => e.url.replace(origin, '')),
    };
    out.entriesAddedByReading = h0.entries.length - out.historyBefore.count;
    console.log(`   history after reading: ${h0.entries.length} entries, ` +
      `index ${h0.currentIndex}  (+${out.entriesAddedByReading} vs arrival)`);
    console.log(`     ${out.historyAfterReading.urls.map((u, i) =>
      `${i}${i === h0.currentIndex ? '*' : ' '} ${u}`).join('\n     ')}`);

    // Mark where the popstate counter stands so the Back below can be
    // attributed exactly one Back's worth of events.
    const callsBefore = await evalJs(cdp, '(window.__ysHistory || []).length');

    console.log('\n   ── ONE browser Back ──');
    const backTo = h0.entries[h0.currentIndex - 1];
    if (!backTo) {
      console.log('   no previous entry exists — nothing to press Back onto');
      out.backImpossible = true;
    } else {
      out.backTargetUrl = backTo.url.replace(origin, '');
      await cdp.send('Page.navigateToHistoryEntry', { entryId: backTo.id });
      out.backTrace = [];
      let prev = 0;
      for (const at of [40, 150, 600, 1500, 3000, 5000]) {
        await sleep(at - prev); prev = at;
        const h = await cdp.send('Page.getNavigationHistory');
        out.backTrace.push({
          at,
          entries: h.entries.length,
          index: h.currentIndex,
          forward: h.entries.length - 1 - h.currentIndex,
          hash: await evalJs(cdp, 'location.hash').catch(() => null),
          text: (await pageText(cdp).catch(() => '')).slice(0, 600),
        });
      }
      for (const t of out.backTrace) {
        console.log(`   BACK -> +${String(t.at).padStart(4)}ms  ` +
          `entries=${t.entries} index=${t.index} forward=${t.forward}  ` +
          `hash=${JSON.stringify(t.hash)}`);
        console.log(`                   page="${t.text.replace(/\n/g, ' ').slice(0, 96)}"`);
      }
      const callsAfter = await evalJs(cdp, 'window.__ysHistory || []');
      out.oneBackCalls = callsAfter.slice(callsBefore);
      out.popstatesForOneBack =
        out.oneBackCalls.filter((c) => c.op === 'popstate').length;
      out.pushStatesForOneBack =
        out.oneBackCalls.filter((c) => c.op === 'pushState').length;
      console.log('   History API calls attributable to that ONE Back:');
      for (const c of out.oneBackCalls) {
        console.log(`     ${c.op.padEnd(12)} ${(c.url || '').padEnd(24)} state=${c.state}`);
      }
      console.log(`   popstate events for ONE Back: ${out.popstatesForOneBack}` +
        (out.popstatesForOneBack > 1
          ? '  <-- go(-1) CASCADE: the engine walked past entries it did not recognise'
          : ''));
      console.log(`   pushState calls for ONE Back: ${out.pushStatesForOneBack}`);

      const settled = out.backTrace[out.backTrace.length - 1];
      const first = out.backTrace[0];
      out.indexDropForOneBack = out.historyAfterReading.index - first.index;
      out.forwardImmediatelyAfterBack = first.forward;
      out.forwardAfterSettling = settled.forward;
      out.forwardTruncatedAfterBack =
        first.forward > 0 && settled.forward < first.forward;
      out.hashAfterBack = settled.hash;
      out.textAfterBack = settled.text;
      // Did Back actually LEAVE the reader? The numbers above say what
      // the history stack did; this says what the reader saw. The
      // reader's own chrome is the marker — the bottom bar's
      // Previous/Next Chapter and the header's Change Version exist on
      // no other page. Before the fix, Back landed back ON the reader
      // (with an extra unknownRoute page pushed underneath the URL);
      // after it, Back pops the reader and the Dashboard is underneath.
      out.readerChromeAfterBack =
        /Next Chapter|Previous Chapter|Change Version|下一章|上一章/i
          .test(settled.text || '');
      out.backLeftTheReader = !out.readerChromeAfterBack;
      console.log(`   still on the reader after Back: ` +
        `${out.readerChromeAfterBack}` +
        (out.readerChromeAfterBack
          ? '  <-- Back did not leave the reader'
          : '  (Back popped the reader, as a pop should)'));
      console.log(`   currentIndex dropped by ${out.indexDropForOneBack} ` +
        'for one Back' +
        (out.indexDropForOneBack > 1 ? '  <-- more than one entry' : ''));
      console.log(`   forward entries: ${out.forwardImmediatelyAfterBack} at +40ms, ` +
        `${out.forwardAfterSettling} at +5s` +
        (out.forwardTruncatedAfterBack
          ? '  <-- the app pushState()d from a non-tip entry and DISCARDED them'
          : ''));
      out.shotBack = await screenshot(cdp, 'bible-after-back');
    }
    out.hashLog = (await hashLog(cdp)).map((e) => e.hash);
    out.historyCalls = await evalJs(cdp, 'window.__ysHistory || []')
      .catch(() => []);
    console.log(`   full hash trace: ${JSON.stringify(out.hashLog)}`);
    const t0 = out.historyCalls[0]?.t ?? 0;
    console.log('   every History API call and popstate, in order:');
    for (const h of out.historyCalls) {
      console.log(`     +${String(h.t - t0).padStart(6)}ms  ${h.op.padEnd(12)} ` +
        `${(h.url || '').padEnd(24)} state=${h.state}`);
    }
  } catch (e) {
    out.error = String(e);
    console.log(`   HARNESS ERROR: ${e.stack || e}`);
  } finally {
    b.close();
  }
  return out;
}

// ── case 7: what browser-history MODE is the engine actually in? ──────
//
// 2026-09-05. Both web-history queue items rest on the same premise —
// the engine runs `SingleEntryBrowserHistory` because the app sets
// `home:` on `GetMaterialApp` rather than using the Router API. The
// first item adds a warning, argued from reading Flutter 3.44.2's
// `lib/web_ui/lib/src/engine/navigation/history.dart`: do NOT reach for
// `SystemNavigator.selectMultiEntryHistory()`, because in multi-entry
// mode Back arrives as `pushRouteInformation`, and a `WidgetsApp` with
// no Router answers that with `pushNamed` — so Back would GROW the
// stack instead of unwinding it.
//
// That warning can be TESTED rather than trusted, and this app hands us
// the experiment for free. `createHistoryForExistingState` picks the
// mode by looking at `history.state` on boot: the `origin` or `flutter`
// marker means single-entry, and ANYTHING ELSE — including the `null`
// that `_writeStateToUrl`'s raw `pushState(null, ...)` leaves behind —
// falls through to `MultiEntriesBrowserHistory`. So: read a chapter,
// then RELOAD. The reload boots on the app's own untagged entry and the
// engine picks multi-entry all by itself, with no `SystemNavigator`
// call and no source edit.
//
// The state each history write CARRIES is the decisive oracle, not an
// inference:
//   single-entry → {"origin": true} then {"flutter": true}
//   multi-entry  → {"serialCount": 0, "state": ...}
// Then one Back, and the question the warning asks: does the history
// stack GROW?
//
// 2026-09-05, what this case actually found: the reload does NOT flip
// the app into multi-entry mode, and `createHistoryForExistingState` is
// not the last word. `NavigatorState.initState`
// (packages/flutter/lib/src/widgets/navigator.dart:3819) calls
// `SystemNavigator.selectSingleEntryHistory()` whenever
// `reportsRouteUpdateToEngine` is true, which it is for the root
// Navigator a `MaterialApp` builds — so whatever the engine inferred
// from the boot state is overridden a frame later. Multi-entry mode is
// therefore NOT reachable from a shipping build of this app by any
// sequence of user actions; testing the warning needs a bundle that
// calls `selectMultiEntryHistory()` after that, which is a throwaway
// experiment build, never a shipped one.
async function runMultiEntryProbe(origin) {
  console.log('\n════ 7. Which BrowserHistory does the engine pick? ════');
  console.log('Read a chapter (so the app leaves a null-state entry at the');
  console.log('tip), then reload onto it. `createHistoryForExistingState`');
  console.log('reads `history.state` and picks the mode. This is the');
  console.log('`selectMultiEntryHistory()` warning, run as an experiment.\n');

  const { b, cdp, booted } = await coldLoad(
    'multientry', origin, origin + '/#/micah/2?v=kjv');
  const out = { booted };
  try {
    let tour = await dismissOnboarding(cdp);
    for (let i = 0; i < 6 && tour.appeared && !tour.dismissed; i++) {
      await sleep(1200);
      await clickText(cdp, SKIP_RE, { timeoutMs: 6000 });
      await sleep(1500);
      const t = await pageText(cdp).catch(() => '');
      tour = { ...tour, dismissed: !TOUR_RE.test(t) };
    }
    if (tour.appeared && !tour.dismissed) {
      throw new Error('the first-run tour would not dismiss');
    }
    await sleep(2000);

    out.stateBeforeReload = await evalJs(cdp, 'JSON.stringify(history.state)');
    out.hashBeforeReload = await evalJs(cdp, 'location.hash');
    console.log(`   hash before reload:  ${JSON.stringify(out.hashBeforeReload)}`);
    console.log(`   history.state before reload: ${out.stateBeforeReload}`);
    out.tipIsUntagged = out.stateBeforeReload === 'null';
    console.log(`   the tip entry is UNTAGGED (raw pushState(null)): ` +
      `${out.tipIsUntagged}`);

    // Reload onto that entry — the ordinary thing a reader does.
    await cdp.send('Page.reload', { ignoreCache: false });
    await waitForFlutter(cdp, 40000);
    await enableSemantics(cdp);
    await sleep(3000);
    let t2 = await dismissOnboarding(cdp, 12000);
    for (let i = 0; i < 4 && t2.appeared && !t2.dismissed; i++) {
      await sleep(1200);
      await clickText(cdp, SKIP_RE, { timeoutMs: 6000 });
      await sleep(1500);
      const t = await pageText(cdp).catch(() => '');
      t2 = { ...t2, dismissed: !TOUR_RE.test(t) };
    }
    await sleep(2500);

    out.stateAfterReload = await evalJs(cdp, 'JSON.stringify(history.state)');
    out.hashAfterReload = await evalJs(cdp, 'location.hash');
    // Do NOT read the mode off `history.state` at this point — measured
    // 2026-09-05, the first run of this case: whichever code wrote LAST
    // owns the state, and `_writeStateToUrl` fires ~3 s after boot and
    // overwrites it with `null` again, so a late read reports `null` in
    // BOTH modes. The engine's own tagging calls, captured at the moment
    // they happened, are the oracle. `__ysHistory` is re-installed per
    // document, so after a reload its first entries are exactly the new
    // engine's boot writes.
    out.bootCallsAfterReload =
      (await evalJs(cdp, 'window.__ysHistory || []')).slice(0, 10);
    // LAST tagging write wins, not the first. Measured 2026-09-05 on the
    // unfixed build: `createHistoryForExistingState` picks multi-entry
    // from the app's untagged tip entry and writes {"serialCount":0},
    // and then `NavigatorState.initState`'s
    // `selectSingleEntryHistory()` tears that down a frame later and
    // writes {"origin":true}/{"flutter":true} over it. A detector that
    // matched the first tag it saw called that boot multi-entry, which
    // is the opposite of what the app ends up running.
    const modeOf = (st) => /"serialCount"/.test(st || '')
      ? 'MultiEntriesBrowserHistory'
      : /"flutter"|"origin"/.test(st || '') ? 'SingleEntryBrowserHistory'
      : null;
    const modes = out.bootCallsAfterReload.map((c) => modeOf(c.state))
      .filter(Boolean);
    out.modeSequence = modes;
    out.mode = modes.length ? modes[modes.length - 1] : 'UNKNOWN';
    console.log(`   hash after reload:   ${JSON.stringify(out.hashAfterReload)}`);
    console.log('   the engine\'s own boot writes on the reloaded document:');
    for (const c of out.bootCallsAfterReload) {
      console.log(`     ${c.op.padEnd(12)} ${(c.url || '').padEnd(24)} state=${c.state}`);
    }
    console.log(`   >>> engine browser-history mode: ${out.mode}` +
      (out.modeSequence && new Set(out.modeSequence).size > 1
        ? `  (inferred at boot as ${out.modeSequence[0]}, then overridden)`
        : ''));

    const hb = await cdp.send('Page.getNavigationHistory');
    out.historyBeforeNav = {
      count: hb.entries.length, index: hb.currentIndex,
      urls: hb.entries.map((e) => e.url.replace(origin, '')),
    };
    console.log(`   history: ${hb.entries.length} entries, index ${hb.currentIndex}`);

    // One in-app navigation, then one Back. In multi-entry mode the
    // engine's `setRouteName(replace: false)` really does push, so this
    // is the first configuration in which Back has somewhere to go.
    const hit = await clickText(cdp, /^(next chapter|下一章)$/i,
      { timeoutMs: 15000, box: [0, 640, 1280, 900] });
    await sleep(3000);
    out.navClicked = hit ? hit.text : null;
    out.hashAfterNav = await evalJs(cdp, 'location.hash');
    const h0 = await cdp.send('Page.getNavigationHistory');
    out.historyAfterNav = {
      count: h0.entries.length, index: h0.currentIndex,
      urls: h0.entries.map((e) => e.url.replace(origin, '')),
    };
    console.log(`   after one chapter step: ${h0.entries.length} entries, ` +
      `index ${h0.currentIndex}, hash ${JSON.stringify(out.hashAfterNav)}`);

    const callsBefore = await evalJs(cdp, '(window.__ysHistory || []).length');
    const backTo = h0.entries[h0.currentIndex - 1];
    if (!backTo) {
      out.backImpossible = true;
      console.log('   no previous entry to press Back onto');
    } else {
      await cdp.send('Page.navigateToHistoryEntry', { entryId: backTo.id });
      out.backTrace = [];
      let prev = 0;
      for (const at of [40, 600, 1500, 3000, 5000]) {
        await sleep(at - prev); prev = at;
        const h = await cdp.send('Page.getNavigationHistory');
        out.backTrace.push({
          at, entries: h.entries.length, index: h.currentIndex,
          forward: h.entries.length - 1 - h.currentIndex,
          hash: await evalJs(cdp, 'location.hash').catch(() => null),
          text: (await pageText(cdp).catch(() => '')).slice(0, 120),
        });
      }
      for (const t of out.backTrace) {
        console.log(`   BACK -> +${String(t.at).padStart(4)}ms  ` +
          `entries=${t.entries} index=${t.index} forward=${t.forward}  ` +
          `hash=${JSON.stringify(t.hash)}`);
      }
      out.oneBackCalls = (await evalJs(cdp, 'window.__ysHistory || []'))
        .slice(callsBefore);
      console.log('   History API calls for that ONE Back:');
      for (const c of out.oneBackCalls) {
        console.log(`     ${c.op.padEnd(12)} ${(c.url || '').padEnd(24)} state=${c.state}`);
      }
      const settled = out.backTrace[out.backTrace.length - 1];
      out.entriesGrewOnBack = settled.entries > out.historyAfterNav.count;
      out.pushStatesOnBack =
        out.oneBackCalls.filter((c) => c.op === 'pushState').length;
      // This is the warning's claim, stated as a number: in multi-entry
      // mode, does Back make the app PUSH?
      console.log(`   entries after Back settled: ${settled.entries} ` +
        `(was ${out.historyAfterNav.count} before Back) — ` +
        `stack GREW on Back: ${out.entriesGrewOnBack}`);
      console.log(`   pushState calls during that Back: ${out.pushStatesOnBack}`);
      out.shot = await screenshot(cdp, 'multientry-after-back');
    }
    out.historyCalls = await evalJs(cdp, 'window.__ysHistory || []')
      .catch(() => []);
  } catch (e) {
    out.error = String(e);
    console.log(`   HARNESS ERROR: ${e.stack || e}`);
  } finally {
    b.close();
  }
  return out;
}

// ── main ─────────────────────────────────────────────────────────────

// ── case 5: the chronology chart's span ──────────────────────────────
//
// 2026-09-04. The chart stopped at Abraham (AM 2187) while the event
// list on the SAME page ran to Revelation, so scrolling right never
// arrived: 「chronology chart为什么不能一直往右边一直到今天」, three
// times, then 「直接做到跟event一致就行了」 and 「我只要看到结果」.
//
// `flutter test` can assert the numbers and the widget tree; it cannot
// show anybody the picture, and a golden here would render every glyph
// as a box because the test font is not the app's. So this case drives
// a real release bundle and captures what a reader actually sees, at
// both ends of the axis, in light and dark, wide and narrow.
async function runChronology(origin) {
  console.log('\n════ 5. Chronology chart — does the axis reach Revelation? ════');
  const shots = [];
  const notes = {};

  // 2026-09-04. Zoom stopped being a multiplier and became a density —
  // pixels per year — so "four clicks of Zoom in" no longer names a
  // level, and the chart no longer OPENS at whole span. Every step below
  // that wants a stated view therefore goes to the floor first and
  // climbs from there.
  //
  // The readout is anchored: `^≈ …` (and the zh forms), because the
  // event lane merges into one semantics node carrying every event
  // title, and an unanchored match finds that lane instead of the
  // control — the same trap the previous pass documented for the chips.
  const YEARS_RE = /(?:≈|约|約)\s*([\d,]+)\s*(?:years in view|年在视图内|年在視圖內)/;

  async function zoomOutFully(cdp) {
    for (let i = 0; i < 12; i++) {
      const hit = await clickText(cdp, /^(Zoom out|缩小|縮小)$/,
        { timeoutMs: 1500 });
      if (!hit) break;
      await sleep(220);
      // The floor is where the readout STOPS saying "years in view" and
      // says "Whole span" instead. Testing for "Whole span" directly
      // would be wrong: the overview strip's own caption says it too, in
      // every view. A disabled Zoom out is a harmless no-op click.
      if (!YEARS_RE.test(await pageText(cdp))) break;
    }
  }

  async function zoomIn(cdp, n) {
    for (let i = 0; i < n; i++) {
      await clickText(cdp, /^(Zoom in|放大)$/, { timeoutMs: 2500 });
      await sleep(320);
    }
  }

  /// Years in view, straight off the control the reader reads.
  async function yearsInView(cdp) {
    const m = YEARS_RE.exec(await pageText(cdp));
    return m ? Number(m[1].replace(/,/g, '')) : null;
  }

  async function capture(label, { width, height, dark, steps }) {
    const b = await Browser.launch(label);
    const cdp = await b.openTab();
    await b.metrics({ width, height, dsr: 2 });
    if (dark) {
      await cdp.send('Emulation.setEmulatedMedia', {
        features: [{ name: 'prefers-color-scheme', value: 'dark' }],
      });
    }
    try {
      await navigate(cdp, origin + '/#/chronology');
      await waitForFlutter(cdp, 40000);
      await enableSemantics(cdp);
      await sleep(2500);
      const tour = await dismissOnboarding(cdp);
      await sleep(1200);
      const out = await steps({ cdp, label });
      return { tour, ...out };
    } finally {
      b.close();
    }
  }

  // (a) The whole-span view — still the floor of the ladder, still the
  //     frame that holds the left end (Genesis 5/11 lifelines) and the
  //     right end (the placed events out to Revelation) at once, which
  //     is the comparison the previous pass was asked for. It is no
  //     longer where the chart OPENS, so this one zooms out to it.
  notes.overview = await capture('chrono-overview', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      await zoomOutFully(cdp);
      await sleep(900);
      const text = await pageText(cdp);
      shots.push(await screenshot(cdp, 'chronology-01-whole-span'));
      return {
        reachesRevelation: /公元 95 年|AD 95/.test(text),
        namesBoundary: /岁数到此为止|ages end here/.test(text),
        atFloor: (await yearsInView(cdp)) === null,
        text: text.slice(0, 1200),
      };
    },
  });

  // (b) Zoomed in and scrolled to the RIGHT-HAND END. The chip for
  //     John on Patmos now scrolls the plot as well as the cursor, so
  //     this is the reader's own route to the far end rather than a
  //     scripted scroll the UI does not offer.
  notes.rightEnd = await capture('chrono-right', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      await zoomOutFully(cdp);
      await zoomIn(cdp, 4);
      // Zooming folds the rows that are no longer in view, which makes
      // the chart shorter and moves the chips UP. `clickText` aims at a
      // semantics node's centre, so let the tree settle at the new
      // height before aiming at anything below the chart.
      await sleep(1600);
      const hit = await clickText(cdp, /^(John Exiled|拔摩)/,
        { box: [0, 0, 900, 1500] });
      await sleep(1400);
      shots.push(await screenshot(cdp, 'chronology-02-right-end-revelation'));
      const text = await pageText(cdp);
      return {
        clickedPatmos: !!hit,
        cursorAtRevelation: /公元 95 年|AD 95/.test(text),
        saysNoLifelines: /此处无生平横条|no lifelines here/.test(text),
      };
    },
  });

  // (b2) A viewport STRADDLING AM 2187 — the case a hard on/off at the
  //      boundary would get wrong. "Abraham dies, aged 175" is AM 2183,
  //      four years short of it, so jumping there centres the viewport
  //      on the boundary: the bars still running (Eber, Abraham, Terah,
  //      Shem) keep full rows and only the rest fold.
  notes.straddle = await capture('chrono-straddle', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      await zoomOutFully(cdp);
      await zoomIn(cdp, 4);
      // Zooming folds the rows that are no longer in view, which makes
      // the chart shorter and moves the chips UP. `clickText` aims at a
      // semantics node's centre, so let the tree settle at the new
      // height before aiming at anything below the chart.
      await sleep(1600);
      // ANCHORED, and boxed to the window. The whole event lane is one
      // merged semantics node whose text is every event title joined by
      // newlines, so an unanchored /Abraham dies/ matches the lane
      // itself — first, since it is above the chips in tree order — and
      // the click lands on a tick instead of the chip. `^` cannot match
      // it (the lane's text starts at "Creation"), and the box keeps
      // out the tick labels scrolled off the right of the plot.
      const hit = await clickText(cdp, /^(Abraham dies|亚伯拉罕)/,
        { box: [0, 0, 900, 1500] });
      await sleep(1400);
      shots.push(await screenshot(cdp, 'chronology-06-straddle-boundary'));
      const text = await pageText(cdp);
      // The whole claim in one number. 0 would mean the fold never
      // fired; 20 would mean it fired as a switch at AM 2187 and threw
      // away bars that are on screen. It has to be in between.
      const m = /(\d+) not in view|(\d+) 条在视图外|(\d+) 條在視圖外/
        .exec(text);
      return {
        clickedAbrahamDies: !!hit,
        foldedRows: m ? Number(m[1] ?? m[2] ?? m[3]) : 0,
      };
    },
  });

  // (c) The LEFT end at the same zoom, for comparison: this is where
  //     the lifelines are, and the ground under them is plain rather
  //     than hatched.
  notes.leftEnd = await capture('chrono-left', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      await zoomOutFully(cdp);
      await zoomIn(cdp, 4);
      // Zooming folds the rows that are no longer in view, which makes
      // the chart shorter and moves the chips UP. `clickText` aims at a
      // semantics node's centre, so let the tree settle at the new
      // height before aiming at anything below the chart.
      await sleep(1600);
      await clickText(cdp, /^(创造|Creation)$/, { box: [0, 0, 900, 1500] });
      await sleep(1400);
      shots.push(await screenshot(cdp, 'chronology-03-left-end-genesis'));
      return {};
    },
  });

  // (d) Dark theme, and (e) a 402 pt phone — the width the team
  //     measures typography at, and the one that bites.
  notes.dark = await capture('chrono-dark', {
    width: 900, height: 1500, dark: true,
    steps: async ({ cdp }) => {
      shots.push(await screenshot(cdp, 'chronology-04-dark'));
      return {};
    },
  });
  notes.narrow = await capture('chrono-narrow', {
    width: 402, height: 1500,
    steps: async ({ cdp }) => {
      shots.push(await screenshot(cdp, 'chronology-05-narrow-402'));
      return {};
    },
  });

  // (f) The 402 pt phone at the right-hand end — the case the fold was
  //     for. Twenty empty rows on a 402 pt screen pushed the event lane,
  //     the chips and the legend clean off it.
  notes.narrowRight = await capture('chrono-narrow-right', {
    width: 402, height: 1500,
    steps: async ({ cdp }) => {
      await zoomOutFully(cdp);
      await zoomIn(cdp, 4);
      // Zooming folds the rows that are no longer in view, which makes
      // the chart shorter and moves the chips UP. `clickText` aims at a
      // semantics node's centre, so let the tree settle at the new
      // height before aiming at anything below the chart.
      await sleep(1600);
      await clickText(cdp, /^(John Exiled|拔摩)/, { box: [0, 0, 402, 1500] });
      await sleep(1400);
      shots.push(await screenshot(cdp, 'chronology-07-narrow-402-right-end'));
      const text = await pageText(cdp);
      return { foldsRows: /not in view|在视图外|在視圖外/.test(text) };
    },
  });

  // (g) THE DEVICE SWEEP. 2026-09-04:「不同devices都要考虑清楚」.
  //
  //     Five form factors, each photographed twice: as the chart OPENS,
  //     and at the deepest level the ladder offers. The number that
  //     matters is on the control itself — how many years are in the
  //     viewport — because that is the quantity the old multiplier hid.
  //     A phone and a desktop at the same rung must report windows in
  //     proportion to their widths, and the deepest rung must be the
  //     same density on all five.
  notes.devices = {};
  for (const dev of [
    { id: 'phone-portrait', width: 390, height: 844 },
    { id: 'phone-landscape', width: 844, height: 390 },
    { id: 'tablet-portrait', width: 834, height: 1194 },
    { id: 'tablet-landscape', width: 1194, height: 834 },
    { id: 'desktop', width: 1280, height: 900 },
  ]) {
    notes.devices[dev.id] = await capture(`chrono-${dev.id}`, {
      width: dev.width, height: dev.height,
      steps: async ({ cdp }) => {
        const opensAt = await yearsInView(cdp);
        shots.push(await screenshot(cdp, `chronology-10-${dev.id}-default`));
        await zoomIn(cdp, 12);
        await sleep(1400);
        const deepest = await yearsInView(cdp);
        shots.push(await screenshot(cdp, `chronology-11-${dev.id}-deepest`));
        // Plot width in points, from the two numbers the reader can see:
        // the axis is 4,098 years and `deepest` of them fill the plot
        // viewport, so the whole plot is 4098/deepest viewports wide.
        return { opensAt, deepest };
      },
    });
  }

  for (const f of shots) console.log(`  captured ${f}`);
  console.log(`  reaches Revelation on screen: ${notes.overview.reachesRevelation}`);
  console.log('  per device — years in view at open, and at the deepest level:');
  for (const [id, v] of Object.entries(notes.devices)) {
    console.log(`    ${id.padEnd(17)} opens ${String(v.opensAt).padStart(5)} yr` +
      `   deepest ${String(v.deepest).padStart(4)} yr`);
  }
  console.log(`  names the computed/placed boundary: ${notes.overview.namesBoundary}`);
  console.log(`  jump-to-Patmos worked: ${notes.rightEnd.clickedPatmos}, ` +
    `cursor lands on AD 95: ${notes.rightEnd.cursorAtRevelation}`);
  console.log(`  straddling AM 2187 folds ${notes.straddle.foldedRows} of ` +
    `20 rows — neither 0 nor 20 is the point`);
  console.log(`  402 pt right-hand end folds the empty rows: ${notes.narrowRight.foldsRows}`);
  return { shots, ...notes };
}

// ── case 8: the version chip actually switching ──────────────────────
//
// Owner report, twice: "switching the Bible version from the header chip
// often does not switch — I have to tap it several times before it
// takes." `main_provider.dart`'s `renderedVersion` doc names the seam
// (`currentVersion` moves on the tap, `renderedVersion` only when the
// decode lands, "forever if the load throws"), so the two things this
// case has to separate are (a) the chip lying about which translation is
// on screen, and (b) the switch silently not happening.
//
// The oracle is the VERSE TEXT, not the chip. 约翰福音 3:1 reads
// "…是犹太人的官。" in 和合本雅伟版 and "…是犹太人一位首领，" in 梁家铿译本;
// the two strings share no substring, so a single semantics dump says
// unambiguously which translation is being rendered. The chip is read
// separately and compared against it — a disagreement is the 2026-08-16
// bug returning.

const VERSIONS_UNDER_TEST = {
  'cuvs-yhwh': {
    menu: /和合本雅伟版\(简体\)/,
    chip: /^(和合本雅伟版|雅伟版)$/,
    body: '犹太人的官',
    langIndex: 2,
  },
  'biblexg-v2': {
    menu: /梁家铿译本\(简体\)/,
    chip: /^(梁家铿\(简\)|梁简)$/,
    body: '犹太人一位首领',
    langIndex: 2,
  },
};
// The chip is ONE semantics node carrying its tooltip and its label
// joined by a newline — measured off the live tree, e.g.
//   [button] y=10 x=644 w=78 h=29 "Change Version\n雅伟版"
// so neither an anchored match on the tooltip nor one on the label finds
// it. Match the tooltip loosely and read the label off the same node.
const CHANGE_VERSION_RE = /(Change Version|切换版本|切換版本)/;
function chipLabelFrom(text) {
  const parts = String(text).split('\n').map((x) => x.trim()).filter(Boolean);
  return parts.length > 1 ? parts[parts.length - 1] : null;
}
// Measured off a real failed switch (2026-09-06), not guessed from
// ui_strings: the snackbar reads "Could not load Bible verses. Please
// check your connection and retry." The first version of this regex
// said "Could not load verses" and matched nothing, which reported a
// silent failure the app was in fact announcing — the exact shape of
// decorative assertion this repo keeps finding.
const SWITCH_FAILED_RE =
    /Could not load Bible verses|无法加载|無法載入|请检查|請檢查|重试|重試/;

/// What the reader can see right now: which label the chip carries, and
/// which translation the verses under it actually came from.
async function readerState(cdp) {
  const s = await semantics(cdp).catch(() => ({ nodes: [] }));
  const nodes = s.nodes || [];
  const text = nodes.map((n) => n.text).join(' │ ');
  const chipNode = nodes.find(
    (n) => CHANGE_VERSION_RE.test(n.text) && n.cy < 220);
  let body = null;
  for (const [key, v] of Object.entries(VERSIONS_UNDER_TEST)) {
    if (text.includes(v.body)) body = key;
  }
  return {
    chip: chipNode ? chipLabelFrom(chipNode.text) : null,
    body,
    overlay: /正在切换译本|正在切換譯本|Loading version/.test(text),
    failureShown: SWITCH_FAILED_RE.test(text),
    text,
  };
}

function chipNames(state) {
  for (const [key, v] of Object.entries(VERSIONS_UNDER_TEST)) {
    if (state.chip && v.chip.test(state.chip)) return key;
  }
  return null;
}

// **The picker is ONE semantics node.** `showLanguageGroupedVersionMenu`
// hangs the whole body — three language pills and every version row —
// inside a single `PopupMenuItem`, and Flutter's `PopupMenuItem` wraps
// its child in `MergeSemantics`. Measured off the live tree:
//
//   [menuitem] y=51 x=442 w=280 h=125
//     "English\n繁體中文\n简体中文\n和合本雅伟版(简体)\n梁家铿译本(简体)"
//
// One node, one rect, no per-row geometry — so `clickText` cannot aim at
// a row, and neither can a screen reader: to VoiceOver this menu is a
// single unlabelled item. That is a real accessibility defect and it is
// recorded here as one, but it is NOT the switching bug: a finger, and
// `Input.dispatchMouseEvent`, both hit-test against the render tree,
// which does have the rows. So the rows are addressed below by the
// layout arithmetic of `_LanguageGroupedVersionBody` instead:
//   pill row  = Padding(8) + TextButton(minimumSize 36) + Padding(8) = 52
//   divider   = 1
//   the rest  = the version rows, evenly (rows in one language tab all
//               carry an editionYear or all carry none)
const MENU_LABELS = [
  'King James Version', 'Lexham English Bible',
  '和合本雅伟版(简体)', '和合本雅偉版(繁體)',
  '梁家铿译本(简体)', '梁家鏗譯本(繁體)',
];
const MENU_PILL_BLOCK = 52;
const MENU_DIVIDER = 1;

/// The merged picker node, or null if the menu is not open.
async function menuNode(cdp) {
  const d = await semantics(cdp).catch(() => ({ nodes: [] }));
  return (d.nodes || []).find(
    (n) => n.role === 'menuitem' && /\n/.test(n.text)) || null;
}

/// The version rows the open menu is currently showing, in order.
function menuRows(node) {
  return String(node.text).split('\n').map((x) => x.trim())
    .filter((x) => MENU_LABELS.includes(x));
}

/// A click that goes to Flutter's RENDER tree, not to the accessibility
/// DOM sitting over it.
///
/// With semantics on, Flutter web overlays real DOM nodes on the canvas
/// and any of them carrying a tap action swallows the click before the
/// framework hit-tests anything. That is a finding in its own right (see
/// runVersionProbe), but a case that wants to know what an ordinary
/// finger does still needs to be able to deliver one while the
/// accessibility tree is on — which is the only way to READ the screen.
/// Dispatching the pointer events straight at the view root does that:
/// they bubble to Flutter's own listener with the real client
/// coordinates and it hit-tests the render tree from there.
async function clickThroughCanvas(cdp, x, y) {
  return evalJs(cdp, `(function () {
    var host = document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('flt-scene-host') || document.body;
    function ev(t, buttons) {
      return new PointerEvent(t, {
        bubbles: true, cancelable: true, composed: true,
        clientX: ${Math.round(x)}, clientY: ${Math.round(y)},
        pointerId: 1, pointerType: 'mouse', isPrimary: true,
        button: 0, buttons: buttons,
      });
    }
    host.dispatchEvent(ev('pointerdown', 1));
    host.dispatchEvent(ev('pointerup', 0));
    return host.tagName + '#' + (host.id || '');
  })()`);
}

async function clickAt(cdp, x, y) {
  for (const type of ['mousePressed', 'mouseReleased']) {
    await cdp.send('Input.dispatchMouseEvent', {
      type, x: Math.round(x), y: Math.round(y), button: 'left', clickCount: 1,
    });
    await sleep(40);
  }
}

/// Language pill `i` of three (en / zh-Hant / zh-Hans), by geometry.
async function clickMenuPill(cdp, node, i) {
  const inner = node.w - 20;
  await clickAt(cdp, node.x + 10 + inner * (i + 0.5) / 3, node.y + 26);
}

/// Version row `i` of `n`, by geometry.
async function clickMenuRow(cdp, node, i, n) {
  const top = node.y + MENU_PILL_BLOCK + MENU_DIVIDER;
  const rowH = (node.h - MENU_PILL_BLOCK - MENU_DIVIDER) / n;
  await clickAt(cdp, node.x + node.w / 2, top + rowH * (i + 0.5));
}

/// ONE tap on the chip and ONE tap on `target`'s row, then watch for up
/// to `settleMs` and report what the reader ends up with.
async function oneSwitchTap(cdp, target,
    { settleMs = 14000, via = 'canvas' } = {}) {
  const t = VERSIONS_UNDER_TEST[target];
  const before = await readerState(cdp);
  const openedChip = await clickText(cdp, CHANGE_VERSION_RE,
    { timeoutMs: 8000, box: [0, 0, 4000, 220] });
  await sleep(800);
  let node = await menuNode(cdp);
  const menuOpened = !!node;
  let rowClicked = null;
  let menuNodes = node ? [{ text: node.text, x: node.x, y: node.y,
                            w: node.w, h: node.h }] : null;
  if (process.env.YS_DUMP_MENU && node) {
    console.log(`   -- menu node -- y=${Math.round(node.y)} ` +
      `x=${Math.round(node.x)} w=${Math.round(node.w)} ` +
      `h=${Math.round(node.h)} rows=${JSON.stringify(menuRows(node))}`);
  }
  if (node) {
    let rows = menuRows(node);
    if (!rows.some((r) => t.menu.test(r))) {
      // Wrong language tab open — switch to the target's, then re-read.
      if (via === 'canvas') {
        const inner = node.w - 20;
        await clickThroughCanvas(cdp,
          node.x + 10 + inner * (t.langIndex + 0.5) / 3, node.y + 26);
      } else {
        await clickMenuPill(cdp, node, t.langIndex);
      }
      await sleep(500);
      node = await menuNode(cdp) || node;
      rows = menuRows(node);
    }
    const idx = rows.findIndex((r) => t.menu.test(r));
    if (process.env.YS_STEP_SHOTS) {
      await screenshot(cdp, `step-${Date.now()}-menu-open`);
    }
    if (idx >= 0) {
      const top = node.y + MENU_PILL_BLOCK + MENU_DIVIDER;
      const rowH = (node.h - MENU_PILL_BLOCK - MENU_DIVIDER) / rows.length;
      const px = node.x + node.w / 2;
      const py = top + rowH * (idx + 0.5);
      if (process.env.YS_DUMP_MENU) {
        console.log(`   -- clicking row ${idx} of ${rows.length} ` +
          `(${rows[idx]}) at ${Math.round(px)},${Math.round(py)}`);
      }
      if (via === 'canvas') {
        await clickThroughCanvas(cdp, px, py);
      } else {
        await clickAt(cdp, px, py);
      }
      rowClicked = { row: rows[idx], index: idx, of: rows.length,
                     x: Math.round(px), y: Math.round(py), via };
      if (process.env.YS_STEP_SHOTS) {
        let prev = 0;
        for (const at of [80, 200, 400, 900, 2000, 4000]) {
          await sleep(at - prev); prev = at;
          const d = await semantics(cdp).catch(() => ({ nodes: [] }));
          const open = (d.nodes || []).some((n) => /Dismiss menu/.test(n.text));
          const mn = (d.nodes || []).find(
            (n) => n.role === 'menuitem' && /\n/.test(n.text));
          console.log(`      +${String(at).padStart(4)}ms menu-open=${open} ` +
            `rows=${mn ? JSON.stringify(menuRows(mn)) : 'none'}`);
          await screenshot(cdp, `step-click-plus${at}`);
        }
      }
    }
  }
  const trace = [];
  let settled = null;
  let prev = 0;
  for (const at of [300, 800, 1500, 3000, 5000, 8000, 11000, settleMs]) {
    if (at > settleMs) break;
    await sleep(at - prev); prev = at;
    const st = await readerState(cdp);
    trace.push({ at, chip: st.chip, body: st.body, overlay: st.overlay,
                 failureShown: st.failureShown });
    if (process.env.YS_TRACE_SHOTS) {
      await screenshot(cdp, `trace-${target}-plus${at}`);
    }
    settled = st;
    if (st.body === target && !st.overlay) break;
  }
  return {
    target,
    menuNodes,
    chipBefore: before.chip, bodyBefore: before.body,
    openedChip: !!openedChip, menuOpened, rowClicked: !!rowClicked,
    chipAfter: settled ? settled.chip : null,
    bodyAfter: settled ? settled.body : null,
    chipNamesAfter: settled ? chipNames(settled) : null,
    failureShown: settled ? settled.failureShown : false,
    trace,
    // The two verdicts this whole case exists to separate.
    // `bodyBefore === target` means this tap asked for what was already
    // on screen — it can only ever read as a pass, so it is excluded
    // from the counts rather than allowed to inflate them.
    noOpTarget: before.body === target,
    switched: !!settled && settled.body === target,
    chipLied: !!settled && settled.body !== null &&
      chipNames(settled) !== null && chipNames(settled) !== settled.body,
  };
}

/// One scenario: cold-load John 3 in 和合本雅伟版, then alternate to
/// 梁家铿译本 and back `rounds` times, ONE tap per switch.
async function runVersionScenario(origin, {
  label, rounds = 4, faults = [], waitBeforeMs = 0, viewport = null,
  via = 'canvas',
}) {
  console.log(`\n── scenario: ${label} ──`);
  for (const f of faults) FAULTS.set(f.path, { ...f });
  const out = { label, via, faults: faults.map((f) => ({ ...f })), taps: [] };
  const { b, cdp, booted } = await coldLoad(
    'version-' + label.replace(/[^a-z0-9]+/gi, '-'), origin,
    origin + '/#/john/3?v=cuvs-yhwh', { viewport });
  out.booted = booted;
  try {
    let tour = await dismissOnboarding(cdp);
    for (let i = 0; i < 6 && tour.appeared && !tour.dismissed; i++) {
      await sleep(1200);
      await clickText(cdp, SKIP_RE, { timeoutMs: 6000 });
      await sleep(1500);
      const t = await pageText(cdp).catch(() => '');
      tour = { ...tour, dismissed: !TOUR_RE.test(t), retries: i + 1 };
    }
    out.tour = tour;
    if (tour.appeared && !tour.dismissed) {
      throw new Error('the first-run tour would not dismiss');
    }
    if (waitBeforeMs) {
      // Let `eagerPreloadAllVersions` finish, so the switch takes the
      // warm-cache path instead of the decode path. biblexg-v2 is LAST
      // in that queue (version_preloader.dart), so "did the reader wait"
      // is exactly what decides which of the two code paths runs.
      await sleep(waitBeforeMs);
    }
    if (process.env.YS_DUMP_SEMANTICS) {
      const d = await semantics(cdp);
      console.log('   ── semantics dump ──');
      for (const n of (d.nodes || [])) {
        console.log(`     [${n.role || '-'}] y=${Math.round(n.y)} ` +
          `x=${Math.round(n.x)} w=${Math.round(n.w)} h=${Math.round(n.h)} ` +
          JSON.stringify(n.text.slice(0, 60)));
      }
      if (process.env.YS_DUMP_SEMANTICS === 'only') {
        out.dumpOnly = true;
        return out;
      }
    }
    const start = await readerState(cdp);
    out.start = { chip: start.chip, body: start.body };
    console.log(`   start: chip=${JSON.stringify(start.chip)} ` +
      `body=${JSON.stringify(start.body)}`);
    if (start.body !== 'cuvs-yhwh') {
      throw new Error('did not start on 和合本雅伟版 John 3 — nothing below ' +
        `would mean anything (body=${JSON.stringify(start.body)})`);
    }
    const order = [];
    for (let i = 0; i < rounds; i++) {
      order.push(i % 2 === 0 ? 'biblexg-v2' : 'cuvs-yhwh');
    }
    for (let i = 0; i < order.length; i++) {
      const r = await oneSwitchTap(cdp, order[i], { via });
      out.taps.push(r);
      console.log(`   tap ${i + 1} -> ${order[i]}: menu=${r.menuOpened} ` +
        `row=${r.rowClicked} switched=${r.switched} ` +
        `chip=${JSON.stringify(r.chipAfter)} body=${JSON.stringify(r.bodyAfter)} ` +
        `chip-lied=${r.chipLied} failure-shown=${r.failureShown}`);
      await screenshot(cdp, `version-${label.replace(/[^a-z0-9]+/gi, '-')}-tap${i + 1}`);
      await sleep(600);
    }
    // Repeat-tap probe: after the LAST tap, tap the same target again,
    // twice. This is the owner's "tap it several times" verbatim, and it
    // is the only thing that can tell "the first tap is a no-op" from
    // "the first tap failed and the second one retried".
    // Retry the target that a failing load would have refused, not
    // whatever the alternating walk happened to end on: "tap it several
    // times" is only a meaningful probe against the version that did
    // not arrive.
    const lastTarget = order[0];
    out.repeatTaps = [];
    for (let i = 0; i < 2; i++) {
      const r = await oneSwitchTap(cdp, lastTarget, { settleMs: 8000, via });
      out.repeatTaps.push(r);
      console.log(`   repeat tap ${i + 1} -> ${lastTarget}: menu=${r.menuOpened} ` +
        `row=${r.rowClicked} switched=${r.switched} body=${JSON.stringify(r.bodyAfter)}`);
    }
    out.errors = await pageErrors(cdp);
    out.console = await evalJs(cdp, 'window.__ysConsole || []').catch(() => []);
  } catch (e) {
    out.error = String(e && e.message ? e.message : e);
    console.log(`   ERROR: ${out.error}`);
  } finally {
    await b.close();
    for (const f of faults) FAULTS.delete(f.path);
  }
  const done = out.taps.filter((t) => t.rowClicked && !t.noOpTarget);
  out.tapsAttempted = done.length;
  out.tapsThatSwitched = done.filter((t) => t.switched).length;
  out.tapsWhereChipLied =
      [...out.taps, ...(out.repeatTaps || [])].filter((t) => t.chipLied).length;
  out.silentFailures = done.filter((t) => !t.switched && !t.failureShown).length;
  return out;
}

/// A coordinate sweep over the open picker. The geometry-derived click on
/// the 梁家铿译本(简体) row did not select it — it flipped the menu to the
/// English tab — so before believing anything about the app this has to
/// establish where each click actually lands.
async function runVersionProbe(origin) {
  console.log('\n════ version picker click probe ════');
  const useSemantics = process.env.YS_NO_SEMANTICS ? false : true;
  console.log(`   accessibility tree: ${useSemantics ? 'ON' : 'OFF'}`);
  const { b, cdp } = await coldLoad('version-probe', origin,
    origin + '/#/john/3?v=cuvs-yhwh', {
      semantics: useSemantics,
      // With the accessibility tree off there is no way to find the
      // tour's Skip button, so the tour has to not appear at all.
      plant: useSemantics ? null : { 'flutter.onboarding.seen.v3': 'true' },
    });
  const rows = [];
  try {
    if (useSemantics) {
      let tour = await dismissOnboarding(cdp);
      for (let i = 0; i < 6 && tour.appeared && !tour.dismissed; i++) {
        await sleep(1200);
        await clickText(cdp, SKIP_RE, { timeoutMs: 6000 });
        await sleep(1500);
        const t = await pageText(cdp).catch(() => '');
        tour = { ...tour, dismissed: !TOUR_RE.test(t) };
      }
    } else {
      await sleep(6000);
      await screenshot(cdp, 'probe-nosem-before-any-click');
    }
    // "x:y" pairs; a bare number keeps the menu's own centre x.
    const pts = (process.env.YS_PROBE_YS || '73,122,158').split(',')
      .map((p) => p.trim())
      .map((p) => p.includes(':')
        ? { x: Number(p.split(':')[0]), y: Number(p.split(':')[1]) }
        : { x: null, y: Number(p) });
    for (const pt of pts) {
      const y = pt.y;
      // Make sure we start from a closed menu on 简体.
      let node = await menuNode(cdp);
      while (node) {
        await cdp.send('Input.dispatchKeyEvent',
          { type: 'keyDown', key: 'Escape', windowsVirtualKeyCode: 27 });
        await cdp.send('Input.dispatchKeyEvent',
          { type: 'keyUp', key: 'Escape', windowsVirtualKeyCode: 27 });
        await sleep(600);
        node = await menuNode(cdp);
      }
      if (useSemantics) {
        await clickText(cdp, CHANGE_VERSION_RE,
          { timeoutMs: 8000, box: [0, 0, 4000, 220] });
      } else {
        // No semantics tree to aim with — the chip's coordinates were
        // measured in the semantics-on run and the layout is identical.
        await clickAt(cdp, 683, 24);
      }
      await sleep(900);
      node = useSemantics ? await menuNode(cdp) : { x: 442, y: 51, w: 280,
        h: 125, text: 'assumed' };
      if (!node) { rows.push({ y, opened: false }); continue; }
      const before = useSemantics ? menuRows(node) : ['(semantics off)'];
      const x = pt.x === null ? Math.round(node.x + node.w / 2) : pt.x;
      await screenshot(cdp, `probe-${x}x${y}-before`);
      if (process.env.YS_CANVAS_CLICK) {
        const host = await clickThroughCanvas(cdp, x, y);
        console.log(`        (canvas click dispatched on ${host})`);
      } else {
        await clickAt(cdp, x, y);
      }
      await sleep(700);
      const after = useSemantics ? await menuNode(cdp) : null;
      const st = useSemantics ? await readerState(cdp)
        : { body: null, chip: null };
      const con = await evalJs(cdp, 'window.__ysConsole || []').catch(() => []);
      const probeLines = process.env.YS_ALL_CONSOLE ? con
        : con.filter((l) => /YSPROBE/.test(l));
      console.log(`        (console lines captured: ${con.length})`);
      await evalJs(cdp, 'window.__ysConsole = []').catch(() => null);
      for (const l of probeLines) console.log(`        ${l}`);
      await screenshot(cdp, `probe-${x}x${y}-after`);
      const r = {
        y, x, nodeY: Math.round(node.y), nodeH: Math.round(node.h),
        rowsBefore: before,
        stillOpen: !!after,
        rowsAfter: after ? menuRows(after) : null,
        body: st.body, chip: st.chip,
      };
      rows.push(r);
      console.log(`   click (${x},${y}) node y=${r.nodeY} h=${r.nodeH} ` +
        `before=${JSON.stringify(before)} -> stillOpen=${r.stillOpen} ` +
        `after=${JSON.stringify(r.rowsAfter)} body=${JSON.stringify(r.body)}`);
    }
  } finally {
    await b.close();
  }
  return rows;
}

// ── case 9: the version picker under assistive technology ────────────
//
// `showLanguageGroupedVersionMenu` hangs its whole body — three language
// pills and every version row — inside ONE `PopupMenuItem`, and
// `PopupMenuItemState.build` wraps every item in `MergeSemantics`. With
// the accessibility tree on, that made the picker a single node:
//
//   [menuitem] y=51 x=442 w=280 h=125
//     "English\n繁體中文\n简体中文\n和合本雅伟版(简体)\n梁家铿译本(简体)"
//
// One node, one rect, one tap action — so a click ANYWHERE inside the
// picker, and every screen-reader activation, ran the first language
// pill. That is a total block on changing the Bible version for anyone
// using VoiceOver, Switch Control or Voice Control, and Flutter web turns
// the semantics tree on by itself when it detects assistive technology.
//
// The oracle here is the URL, not the chip and not the verse text.
// `url_sync_service_web.dart:386` writes `#<path>?v=<currentVersion>`
// after every switch, so `location.hash` says WHICH ROW WAS ACTIVATED
// even when the accessibility tree is off and there is nothing else to
// read on a canvas. That is what makes the semantics-OFF control
// possible at all.
//
// ── Method: ONE set of coordinates, four cells ───────────────────────
//
// The fix removes a `MergeSemantics`, which is a `RenderProxyBox` (see
// `rendering/proxy_box.dart`: it overrides `describeSemanticsConfiguration`
// and NOTHING else). So the picker occupies identical pixels before and
// after it, and coordinates measured on one build are valid on the other.
// That is what makes the comparison worth anything: if each build were
// driven at its own coordinates, "the broken one selected the wrong row"
// could always be "the harness aimed somewhere else".
//
// So the fixed build's semantics-ON pass MEASURES the coordinates off the
// per-target nodes and writes them to `steps.json`; every other cell
// REPLAYS that file. Run it as:
//
//   picker --root build/web-fixed  --out OUT/fixed
//   picker --root build/web-broken --out OUT/broken --steps OUT/fixed/steps.json
//
// A run without `--steps` measures; a run with it replays. Both run the
// tree ON and then OFF.
//
// (An earlier draft of this case had the broken build measure its own
// coordinates from the merged node's rect by layout arithmetic. It does
// not work: `pickerTargets` keyed a node by the FIRST line of its label,
// and the merged node's first line is "English", so the broken build
// reported the whole 320x143 body as the English pill's own node and
// every other leg died with "not an addressable node" — leaving the
// semantics-OFF control with nothing to replay. Measuring on the build
// that has real nodes and replaying on the one that does not is both
// simpler and a stronger control.)

const PICKER_PILLS = ['English', '繁體中文', '简体中文'];
const PICKER_ROW_IDS = {
  'King James Version': 'kjv',
  'Lexham English Bible': 'leb',
  '和合本雅伟版(简体)': 'cuvs-yhwh',
  '和合本雅偉版(繁體)': 'cuvs-yhwh-tr',
  '梁家铿译本(简体)': 'biblexg-v2',
  '梁家鏗譯本(繁體)': 'biblexg-v2-tr',
};
// One walk that never asks for the version already on screen, so every
// step has a positive oracle (the hash MOVES) rather than the weaker
// "nothing happened".
const PICKER_WALK = [
  { pill: '简体中文', row: '梁家铿译本(简体)' },
  { pill: '繁體中文', row: '和合本雅偉版(繁體)' },
  { pill: 'English', row: 'King James Version' },
  { pill: 'English', row: 'Lexham English Bible' },
  { pill: '简体中文', row: '和合本雅伟版(简体)' },
  { pill: '繁體中文', row: '梁家鏗譯本(繁體)' },
];
// Where inside a target's own rect to aim. The defect fired identically
// at every coordinate, so a fix that only works at the centre would be no
// fix at all.
const PICKER_AIMS = [
  { name: 'centre', fx: 0.5, fy: 0.5 },
  { name: 'top-left', fx: 0.12, fy: 0.25 },
  { name: 'bottom-right', fx: 0.88, fy: 0.78 },
];

async function hashVersion(cdp) {
  const h = await evalJs(cdp, 'location.hash').catch(() => '');
  const m = /[?&]v=([^&]+)/.exec(String(h || ''));
  return m ? decodeURIComponent(m[1]) : null;
}

/// Is this node the MERGED picker body rather than one target? Its label
/// carries more than one pill name, joined by newlines. Checking that
/// FIRST is load-bearing: the merged node's first line is "English", so
/// a key-by-first-line lookup mistakes it for the English pill and hands
/// back the whole 320x143 body as that pill's rect.
function isMergedPickerNode(n) {
  return /\n/.test(String(n.text)) &&
    String(n.text).split('\n').map((x) => x.trim())
      .filter((x) => PICKER_PILLS.includes(x)).length > 1;
}

/// Every addressable picker target the accessibility tree exposes, by
/// label. One entry per pill and per version row is what the fix is FOR;
/// before it there is a single node carrying all five labels and this
/// returns nothing at all.
async function pickerTargets(cdp) {
  const d = await semantics(cdp).catch(() => ({ nodes: [] }));
  const out = {};
  for (const n of (d.nodes || [])) {
    if (n.w <= 0 || n.h <= 0) continue;
    if (isMergedPickerNode(n)) continue;
    // A row's node carries its edition year on a second line where the
    // edition has one — "King James Version\n1611 / 1769 revision" — so
    // the key is the FIRST line, not the whole label. Matching the whole
    // label found the three Chinese rows (no edition year) and silently
    // lost both English ones.
    const head = String(n.text).trim().split('\n')[0].trim();
    if (!PICKER_PILLS.includes(head) && PICKER_ROW_IDS[head] === undefined) {
      continue;
    }
    const prev = out[head];
    // The biggest node with that head is the tappable one; a bare Text
    // inside it can carry the same string on a smaller rect.
    if (!prev || n.w * n.h > prev.w * prev.h) {
      out[head] = { x: n.x, y: n.y, w: n.w, h: n.h };
    }
  }
  return out;
}

/// The merged picker node, if the menu is open and still merged. Its
/// existence IS the defect, so it is recorded either way.
async function mergedPickerNode(cdp) {
  const d = await semantics(cdp).catch(() => ({ nodes: [] }));
  return (d.nodes || []).find(isMergedPickerNode) || null;
}

/// The popup's own frame, as the accessibility tree reports it. This is
/// the geometry that must NOT move: the fix removes a `MergeSemantics`,
/// which is a `RenderProxyBox`, so every pixel is supposed to stay where
/// the owner signed it off across three design passes.
async function menuFrame(cdp) {
  const d = await semantics(cdp).catch(() => ({ nodes: [] }));
  const n = (d.nodes || []).find((x) => /^Popup menu$/.test(String(x.text).trim()));
  return n ? { w: Math.round(n.w), h: Math.round(n.h),
               x: Math.round(n.x), y: Math.round(n.y) } : null;
}

function fmtRect(r) {
  return `${Math.round(r.w)}x${Math.round(r.h)}@${Math.round(r.x)},${Math.round(r.y)}`;
}

function aimAt(rect, aim) {
  return {
    x: Math.round(rect.x + rect.w * aim.fx),
    y: Math.round(rect.y + rect.h * aim.fy),
  };
}

async function closeAnyMenu(cdp) {
  for (let i = 0; i < 3; i++) {
    await cdp.send('Input.dispatchKeyEvent',
      { type: 'keyDown', key: 'Escape', windowsVirtualKeyCode: 27 });
    await cdp.send('Input.dispatchKeyEvent',
      { type: 'keyUp', key: 'Escape', windowsVirtualKeyCode: 27 });
    await sleep(350);
  }
}

async function settleHash(cdp, want, ms = 9000) {
  const start = Date.now();
  let v = await hashVersion(cdp);
  while (Date.now() - start < ms) {
    if (v === want) return v;
    await sleep(300);
    v = await hashVersion(cdp);
  }
  return v;
}

/// The measuring pass: drives the picker by the coordinates the
/// accessibility tree itself reports, and records them.
async function pickerMeasure(origin, label) {
  console.log(`\n──── ${label}: accessibility tree ON, coordinates MEASURED ────`);
  const { b, cdp, booted } = await coldLoad('picker-measure', origin,
    origin + '/#/john/3?v=cuvs-yhwh',
    { semantics: true, plant: { 'flutter.onboarding.seen.v3': 'true' } });
  const steps = [];
  let structure = null;
  try {
    await sleep(4000);
    console.log(`   start v=${await hashVersion(cdp)} booted=${booted}`);
    for (const aim of PICKER_AIMS) {
      for (const leg of PICKER_WALK) {
        const before = await hashVersion(cdp);
        await closeAnyMenu(cdp);
        const chip = await clickText(cdp, CHANGE_VERSION_RE,
          { timeoutMs: 8000, box: [0, 0, 4000, 220] });
        await sleep(900);
        if (!chip) {
          steps.push({ aim: aim.name, pillLabel: leg.pill, rowLabel: leg.row,
            error: 'chip not found' });
          continue;
        }
        if (structure === null) {
          const merged = await mergedPickerNode(cdp);
          const targets0 = await pickerTargets(cdp);
          const frame = await menuFrame(cdp);
          structure = {
            frame,
            merged: merged
              ? { text: merged.text, rect: fmtRect(merged) } : null,
            addressable: Object.fromEntries(
              Object.entries(targets0).map(([k, r]) => [k, fmtRect(r)])),
          };
          console.log(`   menu frame: ${frame ? fmtRect(frame) : 'NOT FOUND'}`);
          console.log('   merged picker node: ' + (merged
            ? JSON.stringify(merged.text) + ' ' + fmtRect(merged)
            : 'NONE'));
          console.log('   per-target accessibility nodes: ' +
            JSON.stringify(structure.addressable));
        }
        let targets = await pickerTargets(cdp);
        const pillRect = targets[leg.pill];
        if (!pillRect) {
          steps.push({ aim: aim.name, pillLabel: leg.pill, rowLabel: leg.row,
            before, chip: { x: chip.cx, y: chip.cy },
            error: `pill "${leg.pill}" is not an addressable node` });
          await closeAnyMenu(cdp);
          continue;
        }
        const pillPt = aimAt(pillRect, aim);
        await clickAt(cdp, pillPt.x, pillPt.y);
        await sleep(800);
        targets = await pickerTargets(cdp);
        const rowsShown = Object.keys(targets)
          .filter((k) => PICKER_ROW_IDS[k] !== undefined);
        const rowRect = targets[leg.row];
        if (!rowRect) {
          steps.push({ aim: aim.name, pillLabel: leg.pill, rowLabel: leg.row,
            before, chip: { x: chip.cx, y: chip.cy }, pill: pillPt, rowsShown,
            error: `row "${leg.row}" not shown after the pill tap` });
          await closeAnyMenu(cdp);
          continue;
        }
        const rowPt = aimAt(rowRect, aim);
        await clickAt(cdp, rowPt.x, rowPt.y);
        const want = PICKER_ROW_IDS[leg.row];
        const after = await settleHash(cdp, want);
        const st = { aim: aim.name, pillLabel: leg.pill, rowLabel: leg.row,
          before, want, after, ok: after === want, rowsShown,
          chip: { x: chip.cx, y: chip.cy }, pill: pillPt, row: rowPt,
          pillRect: fmtRect(pillRect), rowRect: fmtRect(rowRect) };
        steps.push(st);
        console.log(`   [${aim.name}] pill ${leg.pill}@${pillPt.x},${pillPt.y}` +
          ` row ${leg.row}@${rowPt.x},${rowPt.y} -> v=${after} ` +
          (st.ok ? 'OK' : `WRONG (wanted ${want})`));
      }
    }
    await screenshot(cdp, 'picker-measure-final');
  } catch (e) {
    console.log(`   ERROR: ${e && e.message ? e.message : e}`);
  } finally {
    await b.close();
  }
  return { steps, structure };
}

/// A replay pass: the SAME pixels, with the accessibility tree in
/// whichever state `withSemantics` says.
async function pickerReplay(origin, steps, withSemantics, label) {
  console.log(`\n──── ${label}: accessibility tree ` +
    `${withSemantics ? 'ON' : 'OFF'}, coordinates REPLAYED ────`);
  const { b, cdp, booted } = await coldLoad(
    'picker-replay-' + (withSemantics ? 'on' : 'off'), origin,
    origin + '/#/john/3?v=cuvs-yhwh',
    { semantics: withSemantics, plant: { 'flutter.onboarding.seen.v3': 'true' } });
  const out = [];
  let structure = null;
  try {
    await sleep(6000);
    console.log(`   start v=${await hashVersion(cdp)} booted=${booted}`);
    for (const s of steps) {
      if (!s.chip || !s.pill || !s.row) {
        out.push({ ...s, skipped: 'the measuring pass never got this far' });
        continue;
      }
      const before = await hashVersion(cdp);
      await closeAnyMenu(cdp);
      await clickAt(cdp, s.chip.x, s.chip.y);
      await sleep(900);
      if (structure === null && withSemantics) {
        const merged = await mergedPickerNode(cdp);
        const targets0 = await pickerTargets(cdp);
        structure = {
          frame: await menuFrame(cdp),
          merged: merged ? { text: merged.text, rect: fmtRect(merged) } : null,
          addressable: Object.fromEntries(
            Object.entries(targets0).map(([k, r]) => [k, fmtRect(r)])),
        };
        console.log('   merged picker node: ' + (merged
          ? JSON.stringify(merged.text) + ' ' + fmtRect(merged) : 'NONE'));
        console.log('   per-target accessibility nodes: ' +
          JSON.stringify(structure.addressable));
      }
      await clickAt(cdp, s.pill.x, s.pill.y);
      await sleep(800);
      await clickAt(cdp, s.row.x, s.row.y);
      const after = await settleHash(cdp, s.want);
      const r = { aim: s.aim, pill: s.pill, row: s.row, chip: s.chip,
        pillLabel: s.pillLabel, rowLabel: s.rowLabel,
        want: s.want, before, after, ok: after === s.want };
      out.push(r);
      console.log(`   [${s.aim}] pill ${s.pillLabel}@${s.pill.x},${s.pill.y} ` +
        `row ${s.rowLabel}@${s.row.x},${s.row.y} -> v=${after} ` +
        (r.ok ? 'OK' : `WRONG (wanted ${s.want})`));
    }
    await screenshot(cdp, 'picker-replay-' + (withSemantics ? 'on' : 'off'));
  } catch (e) {
    console.log(`   ERROR: ${e && e.message ? e.message : e}`);
  } finally {
    await b.close();
  }
  return { steps: out, structure };
}

/// Counts, and refuses to flatter the result.
///
/// A leg whose `want` is the version ALREADY loaded has no oracle: the
/// hash does not have to move for it to read OK, so a build that ignores
/// the tap entirely scores it as a pass. Those legs are counted
/// separately and never folded into the headline number. On the unfixed
/// build they are the only three that "passed" — the picker had done
/// nothing at all.
function pickerTally(name, rows) {
  const driven = rows.filter((s) => !s.skipped && !s.error);
  const moving = driven.filter((s) => s.before !== s.want);
  const inert = driven.filter((s) => s.before === s.want);
  const ok = moving.filter((s) => s.ok).length;
  const inertOk = inert.filter((s) => s.ok).length;
  console.log(`   ${name}: ${ok}/${moving.length} taps that had to CHANGE ` +
    `the version selected what was tapped` +
    (inert.length
      ? `; ${inertOk}/${inert.length} more asked for the version already ` +
        'loaded, where doing nothing also reads OK'
      : '') +
    (rows.length - driven.length
      ? `; ${rows.length - driven.length} of ${rows.length} never reached ` +
        'their row at all' : ''));
  return { ok, moving: moving.length, inertOk, inert: inert.length,
           driven: driven.length, total: rows.length };
}

/// One open picker, painted, with the accessibility tree OFF so the
/// screenshot is the canvas and nothing else. The two builds' shots are
/// then compared byte-for-byte: removing a `MergeSemantics` — a
/// `RenderProxyBox` whose only override is
/// `describeSemanticsConfiguration` — must not move a pixel, and the
/// owner signed these metrics off across three design passes, so "no
/// visual change" is a claim to be measured rather than reasoned.
///
/// It takes TWO shots and reports whether they differ, because a
/// byte-identical pair of screenshots proves nothing at all if the menu
/// failed to open in both: the first version of this took the chip
/// coordinate from a pass run at the pane's own size and then set a
/// 1200x900 viewport, so the click landed on empty chrome, both builds
/// photographed the same closed page, and the comparison "passed"
/// meaninglessly. `openedMenu` is the guard against exactly that. No
/// viewport is set here, on purpose — the recorded coordinate is only
/// valid at the size it was measured at.
async function pickerShot(origin, chip, name) {
  const { b, cdp } = await coldLoad('picker-shot', origin,
    origin + '/#/john/3?v=cuvs-yhwh',
    { semantics: false, plant: { 'flutter.onboarding.seen.v3': 'true' } });
  const out = { closed: null, open: null, openedMenu: false };
  try {
    await sleep(6000);
    out.closed = await screenshot(cdp, name + '-closed');
    await clickAt(cdp, chip.x, chip.y);
    await sleep(1800);
    out.open = await screenshot(cdp, name + '-open');
    out.openedMenu = !readFileSync(out.closed).equals(readFileSync(out.open));
    console.log(`   picker screenshot (a11y off): ${out.open}` +
      (out.openedMenu
        ? ''
        : '  ** THE MENU DID NOT OPEN — this pair proves nothing **'));
  } catch (e) {
    console.log(`   ERROR: ${e && e.message ? e.message : e}`);
  } finally {
    await b.close();
  }
  return out;
}

async function runPicker(origin) {
  console.log('\n════ 9. The version picker under assistive technology ════');
  let measured = null;
  if (STEPS_IN) {
    const raw = JSON.parse(readFileSync(STEPS_IN, 'utf8'));
    measured = { steps: raw.steps || raw, structure: raw.structure || null };
    console.log(`   replaying ${measured.steps.length} recorded coordinates ` +
      `from ${STEPS_IN}`);
  } else {
    measured = await pickerMeasure(origin, 'measure');
    mkdirSync(OUT_DIR, { recursive: true });
    writeFileSync(join(OUT_DIR, 'steps.json'),
      JSON.stringify(measured, null, 2));
    console.log(`   wrote ${join(OUT_DIR, 'steps.json')}`);
  }
  const on = await pickerReplay(origin, measured.steps, true, 'replay');
  const off = await pickerReplay(origin, measured.steps, false, 'replay');
  const firstChip = (measured.steps.find((s) => s.chip) || {}).chip;
  const shot = firstChip
    ? await pickerShot(origin, firstChip, 'picker-open')
    : null;
  console.log('');
  const tOn = pickerTally('semantics ON ', on.steps);
  const tOff = pickerTally('semantics OFF', off.steps);
  let tMeasured = null;
  if (!STEPS_IN) tMeasured = pickerTally('measuring pass (ON)', measured.steps);
  return { measured, on, off, shot,
           tally: { on: tOn, off: tOff, measured: tMeasured } };
}
async function runVersion(origin) {
  if (process.env.YS_PROBE) return { probe: await runVersionProbe(origin) };
  console.log('\n════ 8. The version chip ════');
  console.log('Owner: "switching the version often does not switch — I have');
  console.log('to tap several times before it takes." Oracle is the verse');
  console.log('text of 约翰福音 3:1, which differs between the two editions.\n');

  const LJK = '/assets/assets/biblexg-v2.json';
  const out = {};
  // Scenario selection, for iterating on one case without paying for the
  // whole set: YS_VER_SCENARIOS=healthyImmediate,assetFails
  const only = (process.env.YS_VER_SCENARIOS || '').split(',')
    .map((x) => x.trim()).filter(Boolean);
  const want = (k) => !only.length || only.includes(k);
  // A. Healthy build, no wait — the switch races the eager pre-loader.
  if (want('healthyImmediate')) out.healthyImmediate = await runVersionScenario(origin, {
    label: 'healthy, switch immediately', rounds: 4,
  });
  // B. Healthy build, pre-load finished — the warm-cache path.
  if (want('healthyWarm')) out.healthyWarm = await runVersionScenario(origin, {
    label: 'healthy, pre-load settled', rounds: 4, waitBeforeMs: 45000,
  });
  // C. The LJK asset fails outright. This is the "forever if the load
  //    throws" branch, and the question is what the reader is told.
  if (want('assetFails')) out.assetFails = await runVersionScenario(origin, {
    label: 'LJK asset 500s', rounds: 2,
    faults: [{ path: LJK, status: 500 }],
  });
  // D. The LJK asset fails for the first few requests and then works.
  //    This is the owner's report reproduced literally: does the SECOND
  //    tap recover, or is it a no-op that has to be worked around?
  if (want('assetFailsThenRecovers')) out.assetFailsThenRecovers = await runVersionScenario(origin, {
    label: 'LJK asset 500s 4x then serves', rounds: 2,
    faults: [{ path: LJK, status: 500, remaining: 4 }],
  });
  // E. The LJK asset is merely slow.
  if (want('assetSlow')) out.assetSlow = await runVersionScenario(origin, {
    label: 'LJK asset delayed 6s', rounds: 2,
    faults: [{ path: LJK, delayMs: 6000 }],
  });
  // The owner reports this from an iPad, so the reader's own layout at
  // that size has to be exercised too — the chip falls back to its
  // narrowLabel there and the menu is positioned from the chip's rect.
  if (want('iPadPortrait')) out.iPadPortrait = await runVersionScenario(origin, {
    label: 'iPad portrait 834x1194', rounds: 4,
    viewport: { width: 834, height: 1194, dsr: 2, mobile: true },
  });
  if (want('iPadLandscape')) {
    out.iPadLandscape = await runVersionScenario(origin, {
      label: 'iPad landscape 1194x834', rounds: 4,
      viewport: { width: 1194, height: 834, dsr: 2, mobile: true },
    });
  }
  // F. The same healthy build, driven through the ACCESSIBILITY DOM
  //    instead of the render tree — i.e. what a click does while
  //    Flutter's semantics overlay is up. Everything above dispatches
  //    the pointer at the view root on purpose so it reaches the render
  //    tree; this one does not.
  if (want('a11yOverlay')) out.a11yOverlay = await runVersionScenario(origin, {
    label: 'healthy, clicks land on the accessibility overlay', rounds: 2,
    via: 'dom',
  });
  return out;
}

async function main() {
  const s = await stat(join(WEB_ROOT, 'index.html')).catch(() => null);
  if (!s) {
    console.error(`No index.html under ${WEB_ROOT}. Build first:\n` +
      `  ~/flutter/bin/flutter build web --release --no-web-resources-cdn`);
    process.exit(2);
  }
  // `--root` is normally <repo>/build/web; netlify.toml sits two up.
  const repoRoot = resolvePath(WEB_ROOT, '..', '..');
  const songMedia = await loadSongMediaProxies(repoRoot);
  const { srv, port } = await startServer(WEB_ROOT, songMedia);
  const origin = `http://127.0.0.1:${port}`;
  console.log(`Serving ${WEB_ROOT}`);
  console.log(`        at ${origin}  (local only — this harness has no prod path)`);
  console.log(`song-media proxies from netlify.toml: ` +
    `${songMedia.size ? [...songMedia.keys()].join(', ') : 'NONE FOUND — /songs/:id/score will fail'}`);
  console.log(`Artifacts -> ${OUT_DIR}`);

  const out = {};
  try {
    if (CMD === 'all' || CMD === 'routes') out.routes = await runRoutes(origin);
    if (CMD === 'all' || CMD === 'sermon' || CMD === 'history') {
      out.sermon = await runSermon(origin, { withPlant: true });
      out.sermonControl = await runSermon(origin, { withPlant: false });
    }
    if (CMD === 'all' || CMD === 'history' || CMD === 'bible') {
      out.bible = await runBible(origin);
      out.multiEntry = await runMultiEntryProbe(origin);
    }
    if (CMD === 'all' || CMD === 'youtube') out.youtube = await runYoutube(origin);
    if (CMD === 'all' || CMD === 'typography') out.typography = await runTypography(origin);
    if (CMD === 'all' || CMD === 'chronology') {
      out.chronology = await runChronology(origin);
    }
    if (CMD === 'all' || CMD === 'version') out.version = await runVersion(origin);
    if (CMD === 'all' || CMD === 'picker') out.picker = await runPicker(origin);
  } finally {
    srv.close();
  }

  console.log('\n════ summary ════');
  if (out.routes) {
    for (const r of out.routes) {
      console.log(`  ${r.hash}: booted=${r.engineBooted} hash-survived=${r.hashOk} ` +
        `right-page=${r.pageOk} state-restored=${r.stateOk}` +
        (r.error ? ` ERROR=${r.error}` : ''));
    }
    const ai = out.routes.find((r) => r.hash === '#/settings/ai');
    const bare = out.routes.find((r) => r.hash === '#/settings');
    if (ai && bare) {
      const same = (ai.text || '') === (bare.text || '');
      console.log(`  /settings/ai vs bare /settings render identical text: ${same}` +
        (same ? '  <-- the :section slug changed nothing on screen' : ''));
    }
  }
  if (out.sermon) {
    console.log(`  sermon address bar: names-sermon=${out.sermon.namesSermon} ` +
      `ever-showed-bible=${out.sermon.everWentBible} ` +
      `push-added-history-entry=${out.sermon.pushAddedEntry} ` +
      `back-showed-list=${out.sermon.backShowsList} ` +
      `forward-restored=${out.sermon.forwardRestoredDetail}`);
  }
  if (out.sermonControl) {
    console.log(`  sermon CONTROL (no plant): names-sermon=${out.sermonControl.namesSermon} ` +
      `push-added-history-entry=${out.sermonControl.pushAddedEntry} ` +
      `back-showed-list=${out.sermonControl.backShowsList} ` +
      `forward-available=${!out.sermonControl.forwardGone}`);
  }
  if (out.bible) {
    console.log(`  bible reader history: chapter-nav-worked=${out.bible.chapterNavWorked} ` +
      `entries-added-by-reading=${out.bible.entriesAddedByReading} ` +
      `popstates-for-one-Back=${out.bible.popstatesForOneBack} ` +
      `index-drop-for-one-Back=${out.bible.indexDropForOneBack} ` +
      `forward-truncated=${out.bible.forwardTruncatedAfterBack} ` +
      `back-left-the-reader=${out.bible.backLeftTheReader}`);
  }
  if (out.multiEntry) {
    console.log(`  engine history mode after a reload onto the app's own ` +
      `untagged entry: ${out.multiEntry.mode}` +
      (out.multiEntry.backImpossible ? ' (no Back step)' :
        `; one Back GREW the stack: ${out.multiEntry.entriesGrewOnBack}`));
  }
  if (out.youtube) {
    console.log(`  youtube: src-jsapi=${out.youtube.srcHasJsApi} ` +
      `src-origin=${out.youtube.srcHasOrigin} ` +
      `listening-posts=${out.youtube.listeningCount} ` +
      `player-replies=${out.youtube.playerReplies} ` +
      `currentTime-frames=${out.youtube.currentTimeFrames} ` +
      `reachable=${out.youtube.youtubeReachable} ` +
      `remounted=${out.youtube.remounted} start=${out.youtube.startParam}`);
  }
  if (out.typography) {
    console.log(`  typography: on-detail=${out.typography.onDetail} ` +
      `shots=${(out.typography.shots || []).length}`);
  }
  if (out.version) {
    for (const sc of Object.values(out.version)) {
      console.log(`  version [${sc.label}]: ` +
        (sc.error ? `ERROR ${sc.error}` :
          `${sc.tapsThatSwitched}/${sc.tapsAttempted} single taps switched, ` +
          `${sc.silentFailures} failed with NOTHING told to the reader, ` +
          `chip lied on ${sc.tapsWhereChipLied}`));
    }
  }
  out.clicks = CLICK_LOG;
  const ambiguousClicks = CLICK_LOG.filter((c) => c.candidates > 1);
  if (ambiguousClicks.length) {
    console.log(`\n  ⚠ ${ambiguousClicks.length} clickText() call(s) matched more than one node ` +
      `this run — see out.clicks in results.json:`);
    for (const c of ambiguousClicks) {
      console.log(`    ${c.site}: ${c.candidates} candidates, clicked ${JSON.stringify(c.matchedText)}`);
    }
  }
  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(join(OUT_DIR, 'results.json'), JSON.stringify(out, null, 2));
  console.log(`\n  machine-readable results: ${join(OUT_DIR, 'results.json')}`);

  // ── regression gate ─────────────────────────────────────────────────
  //
  // Added 2026-09-03, when this harness's first two findings were fixed.
  // Both live here rather than in `flutter test` because neither is
  // reachable from the VM: one is a lazily-built `ListView` in a real
  // release bundle, and the other is a `popstate` listener behind
  // `dart:js_interop`. Until now every case printed a number and exited
  // 0 regardless, so a regression would have had to be noticed by eye.
  //
  // Only the two behaviours this pass actually fixed are gated. Nothing
  // that depends on the network is (the YouTube handshake, the CDC score
  // PDF), and a case that errored inside the harness is reported as
  // INCONCLUSIVE rather than counted as a pass.
  const gate = [];
  if (out.routes) {
    const ai = out.routes.find((r) => r.hash === '#/settings/ai');
    const bare = out.routes.find((r) => r.hash === '#/settings');
    if (!ai || !bare || ai.error || bare.error) {
      gate.push(['INCONCLUSIVE', '/settings/:section',
        'the /settings/ai or /settings case did not complete']);
    } else if ((ai.text || '') === (bare.text || '')) {
      gate.push(['FAIL', '/settings/:section',
        '/#/settings/ai renders identical text to bare /#/settings — the ' +
        'section slug scrolled nothing']);
    } else if (!ai.stateOk || ai.visibleOk === false) {
      gate.push(['FAIL', '/settings/:section',
        '/#/settings/ai differs from bare /settings but the AI section ' +
        'header is not inside the viewport — built is not the same as ' +
        `visible (matched at y=${JSON.stringify(ai.matchedAnywhere)})`]);
    } else {
      gate.push(['PASS', '/settings/:section',
        'the AI section is scrolled into view and the page differs from ' +
        'bare /settings']);
    }
  }
  // 2026-09-06. Gated, not merely reported, for the same reason the two
  // above are: `flutter test` cannot see it. The failure only exists once
  // Flutter web's accessibility tree is on and its DOM overlay is taking
  // the clicks, and the widget-level tap (`tester.tap`, a render-tree hit
  // test) passed throughout. A reader using VoiceOver, Switch Control or
  // Voice Control could not change the Bible version at all, so a
  // regression here is a total block on a core feature and should stop a
  // release rather than print a number.
  //
  // The semantics-OFF replay is the control and is NOT gated on its own:
  // it is what tells "the picker is broken for assistive technology"
  // apart from "the harness aimed at the wrong pixels", and it passed on
  // the unfixed build.
  if (out.picker) {
    const t = out.picker.tally.on;
    const merged = (out.picker.on.structure || {}).merged;
    const offT = out.picker.tally.off;
    if (!t || t.driven === 0 || !offT || offT.ok !== offT.moving) {
      gate.push(['INCONCLUSIVE', 'version picker under assistive technology',
        'the semantics-OFF control did not itself pass, so a semantics-ON ' +
        'failure cannot be attributed to the accessibility tree']);
    } else if (merged) {
      gate.push(['FAIL', 'version picker under assistive technology',
        'the whole picker is still ONE accessibility node ' +
        JSON.stringify(merged.text) + ' — every pill and every row ' +
        'collapsed into ' + merged.rect]);
    } else if (t.ok !== t.moving) {
      gate.push(['FAIL', 'version picker under assistive technology',
        `${t.ok}/${t.moving} taps selected what was tapped with the ` +
        `accessibility tree ON, against ${offT.ok}/${offT.moving} at the ` +
        'identical coordinates with it OFF']);
    } else {
      gate.push(['PASS', 'version picker under assistive technology',
        `${t.ok}/${t.moving} taps selected what was tapped with the tree ` +
        `ON and ${offT.ok}/${offT.moving} with it OFF, at the same ` +
        'coordinates; no merged picker node']);
    }
  }
  for (const [label, s] of [['sermon', out.sermon],
                            ['sermon CONTROL', out.sermonControl]]) {
    if (!s) continue;
    // 2026-09-06. `out.openedRow` used to be recorded and never checked —
    // the exact "decorative assertion" shape this file's own header warns
    // against. A click that lands on the topic's own header (collapsing
    // it back up) still returns a truthy `hit`, so without this the walk
    // below would carry on reading a Bible-reader page's worth of
    // nothing and blame Back for it.
    if (s.error || !s.openedRow || !s.backTrace) {
      gate.push(['INCONCLUSIVE', `Opened sermon row (${label})`,
        'the walk did not reach the row-click step']);
    } else if (s.openedRowIsGroupHeader) {
      gate.push(['FAIL', `Opened sermon row (${label})`,
        `the click matched the topic header ("${s.openedRow}"), not a ` +
        'sermon row — it likely re-collapsed the group instead of ' +
        `opening one (candidates=${s.openedRowCandidates})`]);
    } else if (!s.openedRowIsExpectedSermon) {
      gate.push(['FAIL', `Opened sermon row (${label})`,
        `the click landed on "${s.openedRow}", not the expected sermon ` +
        `title (candidates=${s.openedRowCandidates})`]);
    } else if (s.openedRowCandidates > 1) {
      gate.push(['FAIL', `Opened sermon row (${label})`,
        `/Temptation/i matched ${s.openedRowCandidates} semantics nodes — ` +
        'it happened to click the right one this run, but an unanchored ' +
        'multi-candidate match is exactly what made the chronology case ' +
        'photograph the wrong thing for its whole life']);
    } else {
      gate.push(['PASS', `Opened sermon row (${label})`,
        `exactly one node matched /Temptation/i and it was the expected ` +
        'sermon title']);
    }
    if (s.error || !s.openedRow || !s.backTrace) {
      gate.push(['INCONCLUSIVE', `Back (${label})`,
        'the walk did not reach the Back step']);
    } else if (!s.backShowsList) {
      gate.push(['FAIL', `Back (${label})`,
        'one Back did not land on /#/sermons — it unwound more than one ' +
        `page (hash after Back: ${JSON.stringify(s.hashAfterBack)})`]);
    } else {
      gate.push(['PASS', `Back (${label})`,
        'one Back returns to the sermon list']);
    }
    // Reported, never gated. Forward is unreachable by construction while
    // the app uses `home:` instead of the Router API: Flutter's
    // `SingleEntryBrowserHistory` re-pushes its own entry on every
    // popstate, which truncates the forward list. Gating on it would be
    // gating on a migration this repo has not made.
    gate.push(['KNOWN-GAP', `Forward (${label})`,
      `forward entries after Back: ${s.forwardEntriesAfterSettling ?? 0} ` +
      '— single-entry browser history, see docs/url-routing-plan.md §5']);
  }
  if (out.bible) {
    const bi = out.bible;
    if (bi.error || !bi.chapterNavWorked || !bi.backTrace) {
      gate.push(['INCONCLUSIVE', 'Back (Bible reader)',
        'the reader walk did not reach the Back step — the Next-chapter ' +
        'control was not found, or no history entry existed to go back to']);
    } else if (bi.popstatesForOneBack > 1) {
      // The measured signature of the queue item: our raw pushState wrote
      // a null-state entry the engine does not recognise, so its
      // onPopState `else` branch does go(-1) and keeps going until it
      // reaches its own "flutter" entry, then dispatches pushRoute.
      gate.push(['FAIL', 'Back (Bible reader)',
        `one Back produced ${bi.popstatesForOneBack} popstate events and ` +
        `dropped currentIndex by ${bi.indexDropForOneBack} — the engine ` +
        'walked past history entries it did not recognise (raw pushState ' +
        'with a null state) instead of popping once']);
    } else if (bi.backTrace[bi.backTrace.length - 1].entries >
               bi.historyAfterReading.count) {
      // The popstate count ALONE is not a sufficient oracle, and finding
      // that out is what this branch is. The multi-entry experiment
      // build measured on 2026-09-05 produces exactly ONE popstate per
      // Back — and then PUSHES three entries, because Back arrives as
      // `pushRouteInformation`. A gate that only counted popstates
      // called that a PASS. Back must also not GROW the stack.
      gate.push(['FAIL', 'Back (Bible reader)',
        `one Back left ${bi.backTrace[bi.backTrace.length - 1].entries} ` +
        `history entries where there were ${bi.historyAfterReading.count} ` +
        'before it — Back PUSHED instead of unwinding']);
    } else if (bi.entriesAddedByReading !== 0) {
      gate.push(['FAIL', 'Back (Bible reader)',
        `reading two chapters added ${bi.entriesAddedByReading} browser ` +
        'history entries — the reader is writing entries the engine does ' +
        'not own again (a raw pushState in _writeStateToUrl)']);
    } else if (bi.forwardTruncatedAfterBack) {
      gate.push(['FAIL', 'Back (Bible reader)',
        'the forward entries that existed right after Back were gone ' +
        '~350 ms later — something pushState()d from a non-tip entry']);
    } else if (!bi.backLeftTheReader) {
      gate.push(['FAIL', 'Back (Bible reader)',
        'Back did not leave the reader — the reader\'s own chrome ' +
        '(Previous/Next Chapter, Change Version) is still on screen five ' +
        'seconds later']);
    } else {
      gate.push(['PASS', 'Back (Bible reader)',
        'reading chapters adds no browser entries, one Back produces ' +
        'exactly one popstate, the stack does not grow, no forward ' +
        'entries are discarded, and Back pops the reader']);
    }
    // NOT gated, and the reason is worth writing down: `currentIndex`
    // does NOT fall when Back works correctly here. The engine's
    // origin-entry branch re-pushes its own "flutter" entry the instant
    // the popstate arrives, so the index is back where it started within
    // the same tick. An earlier version of this gate asserted
    // `indexDrop >= 1` and failed the FIXED build for it. The index is
    // reported below as data, never as a verdict.
    gate.push(['MEASURED', 'Back index delta (Bible reader)',
      `currentIndex moved by ${bi.indexDropForOneBack} and popstate fired ` +
      `${bi.popstatesForOneBack} time(s) for one Back; reading two ` +
      `chapters added ${bi.entriesAddedByReading} browser entries`]);
  }
  if (out.multiEntry && !out.multiEntry.error) {
    // Reported, never gated — this case is a MEASUREMENT of what the
    // engine does in the other mode, not a behaviour the app promises.
    gate.push(['MEASURED', 'multi-entry mode',
      `a reload onto the app's own untagged history entry put the engine ` +
      `in ${out.multiEntry.mode}` +
      (out.multiEntry.backImpossible ? '' :
        `; one Back then grew the history stack: ` +
        `${out.multiEntry.entriesGrewOnBack}`)]);
  }
  if (out.version) {
    for (const sc of Object.values(out.version)) {
      if (sc.error) {
        gate.push(['INCONCLUSIVE', `version switch (${sc.label})`, sc.error]);
        continue;
      }
      if (!sc.tapsAttempted) {
        gate.push(['INCONCLUSIVE', `version switch (${sc.label})`,
          'no tap ever reached a version row']);
        continue;
      }
      if (sc.via === 'dom') {
        // Not a gate. This scenario drives clicks at the accessibility
        // DOM instead of the render tree, and it FAILS by design as of
        // 2026-09-06: `PopupMenuItem` wraps its child in
        // `MergeSemantics`, so the whole version picker is ONE merged
        // node whose tap action is the first language pill's. Every tap
        // anywhere in the picker selects English and no version can be
        // chosen at all. Reproduced at 8+ coordinates, 100%; with the
        // accessibility tree off the identical click selects correctly.
        // Fixing it means restructuring a menu whose custom-entry
        // ancestor crashed iPhone Safari once already, so it is reported
        // for a decision rather than gated.
        gate.push(['KNOWN-GAP', `version picker via the accessibility DOM`,
          `${sc.tapsThatSwitched}/${sc.tapsAttempted} taps switched — the ` +
          'picker is one merged semantics node and every tap in it fires ' +
          'the first language pill']);
        continue;
      }
      if (sc.tapsWhereChipLied) {
        gate.push(['FAIL', `version chip honesty (${sc.label})`,
          `the chip named a translation the verses did not come from on ` +
          `${sc.tapsWhereChipLied} tap(s)`]);
      } else {
        gate.push(['PASS', `version chip honesty (${sc.label})`,
          'the chip never named a translation the body was not showing']);
      }
      // Gated only where every tap is EXPECTED to succeed. The
      // fault-injection scenarios deliberately break the asset, so a
      // tap failing there is the scenario working, not a regression.
      if (!sc.faults.length) {
        if (sc.tapsThatSwitched < sc.tapsAttempted) {
          gate.push(['FAIL', `version switch (${sc.label})`,
            `${sc.tapsThatSwitched}/${sc.tapsAttempted} single taps ` +
            'switched on a healthy build — one tap must switch']);
        } else {
          gate.push(['PASS', `version switch (${sc.label})`,
            `${sc.tapsThatSwitched}/${sc.tapsAttempted} single taps ` +
            'switched, and every repeat tap did too']);
        }
      }
      // NEVER gated, and the reason matters: `silentFailures` counts
      // taps that did not switch AND showed nothing IN THE ACCESSIBILITY
      // TREE. Measured 2026-09-06, the app DOES show a snackbar reading
      // "Could not load Bible verses. Please check your connection and
      // retry." — it is in the +3000 ms screenshot of the 500s scenario
      // — but that snackbar does not appear in the semantics dump this
      // oracle reads, so the number below is a statement about the
      // accessibility tree, not about what a sighted reader sees. An
      // earlier version of this gate called it a silent failure and was
      // wrong. That the message is missing from the accessibility tree
      // is itself worth someone's attention, separately.
      gate.push(['MEASURED', `version switch feedback (${sc.label})`,
        `${sc.tapsThatSwitched}/${sc.tapsAttempted} taps switched; ` +
        `${sc.silentFailures} failing tap(s) put no message in the ` +
        'accessibility tree (the on-screen snackbar is not in it either)']);
    }
  }
  if (gate.length) {
    console.log('\n════ regression gate ════');
    for (const [verdict, what, why] of gate) {
      console.log(`  ${verdict.padEnd(12)} ${what}\n               ${why}`);
    }
  }
  const failed = gate.filter(([v]) => v === 'FAIL');
  process.exit(failed.length ? 1 : 0);
}

main();
