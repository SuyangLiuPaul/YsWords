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
//   history     alias for `sermon` (same walk; Back/Forward is the point)
//   youtube     the enablejsapi handshake and the language switch
//   typography  sermon 004 at 402x874, captured, with the paragraph gap
//               measured off the live layout
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
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { readFile, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join, extname, resolve as resolvePath } from 'node:path';

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

// ── argv ─────────────────────────────────────────────────────────────

const VALUE_FLAGS = new Set(['--root', '--out']);
const argv = process.argv.slice(2);
function flag(name, dflt) {
  const i = argv.indexOf(name);
  return i < 0 ? dflt : argv[i + 1];
}
const WEB_ROOT = resolvePath(flag('--root', 'build/web'));
const OUT_DIR = resolvePath(flag('--out', 'build/web-verify'));
const positional = argv.filter((a, i) =>
  !a.startsWith('--') && !VALUE_FLAGS.has(argv[i - 1]));
const CMD = positional[0] || 'all';
const KNOWN = ['all', 'routes', 'sermon', 'history', 'youtube', 'typography',
               'chronology'];
if (!KNOWN.includes(CMD)) {
  console.error(`Unknown subcommand ${JSON.stringify(CMD)}. One of: ${KNOWN.join(', ')}`);
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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

function startServer(root, songMedia = new Map()) {
  return new Promise((resolve, reject) => {
    const srv = createServer(async (req, res) => {
      try {
        let p = decodeURIComponent(req.url.split('?')[0]);
        if (p.includes('..')) { res.writeHead(400); return res.end('no'); }
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
    History.prototype.pushState = function (s, t, u) {
      try { window.__ysHistory.push({ op: 'pushState', url: String(u), t: Date.now() }); } catch (e) {}
      return ps.apply(this, arguments);
    };
    History.prototype.replaceState = function (s, t, u) {
      try { window.__ysHistory.push({ op: 'replaceState', url: String(u), t: Date.now() }); } catch (e) {}
      return rs.apply(this, arguments);
    };
    window.addEventListener('popstate', function () {
      try { window.__ysHistory.push({ op: 'popstate', url: location.hash, t: Date.now() }); } catch (e) {}
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
  static async launch(label) {
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
async function clickText(cdp, re, { index = 0, timeoutMs = 15000 } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const s = await semantics(cdp);
    const hits = (s.nodes || []).filter(
      (n) => re.test(n.text) && n.w > 0 && n.h > 0 && n.cy > 0);
    if (hits[index]) {
      const n = hits[index];
      for (const type of ['mousePressed', 'mouseReleased']) {
        await cdp.send('Input.dispatchMouseEvent', {
          type, x: n.cx, y: n.cy, button: 'left', clickCount: 1,
        });
        await sleep(40);
      }
      return n;
    }
    await sleep(300);
  }
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
async function coldLoad(label, origin, url, { plant = null, viewport = null } = {}) {
  const b = await Browser.launch(label);
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
  await enableSemantics(cdp);
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
    const topic = await clickText(cdp, /^Baptism\b/i, { timeoutMs: 20000 });
    console.log(`   expanded topic: ${topic ? JSON.stringify(topic.text.slice(0, 60)) : 'NOT FOUND'}`);
    await sleep(2000);
    const hit = await clickText(cdp, /Temptation/i, { timeoutMs: 20000 });
    console.log(`   clicked a sermon row: ${hit ? JSON.stringify(hit.text.slice(0, 80)) : 'NOT FOUND'}`);
    out.openedRow = hit ? hit.text.slice(0, 120) : null;
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
      console.log(`     +${String(h.t - t0).padStart(6)}ms  ${h.op.padEnd(12)} ${h.url}`);
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

async function runYoutube(origin) {
  console.log('\n════ 2. YouTube language-switch handshake ════');
  console.log('Claim under test (youtube_embed_web.dart + _src.dart):');
  console.log('  (i)   the iframe src carries enablejsapi=1 and origin');
  console.log('  (ii)  the page posts `listening` on load and 10x at 500ms');
  console.log('  (iii) the player answers with frames carrying currentTime');
  console.log('  (iv)  a language switch re-mounts the embed with ?start=N');
  console.log('(i), (ii) and (iv) are observable regardless of network.');
  console.log('(iii) needs youtube-nocookie.com to actually answer from');
  console.log('this machine — reported separately, never merged with (i).\n');

  const { b, cdp, booted } = await coldLoad(
    'youtube', origin, origin + '/#/videos/cross');
  const out = { booted };
  try {
    await dismissOnboarding(cdp);
    await sleep(2000);
    console.log(`   /#/videos/cross text: ${(await pageText(cdp)).slice(0, 260)}`);

    // The embed only mounts after a tap — videos_page.dart:592's poster
    // InkWell. Nothing autoplays on arrival, by design.
    const poster = await clickText(cdp, /Standing at the Cross|Play|播放|第1集|Episode 1/i,
      { timeoutMs: 12000 });
    console.log(`   tapped: ${poster ? JSON.stringify(poster.text.slice(0, 70)) : 'NOTHING MATCHED'}`);
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
    console.log('\n   ── language switch ──');
    const chip = await clickText(cdp, /粤语|廣東話|Cantonese|國語|普通话|Mandarin|中文/i,
      { timeoutMs: 10000 });
    console.log(`   tapped language chip: ${chip ? JSON.stringify(chip.text) : 'NOTHING MATCHED'}`);
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

  // (a) The default view: zoom 1, whole span on one screen. The left
  //     end (Genesis 5/11 lifelines) and the right end (the placed
  //     events out to Revelation) are both in this one frame, which is
  //     the comparison asked for.
  notes.overview = await capture('chrono-overview', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      const text = await pageText(cdp);
      shots.push(await screenshot(cdp, 'chronology-01-whole-span'));
      return {
        reachesRevelation: /公元 95 年|AD 95/.test(text),
        namesBoundary: /岁数到此为止|ages end here/.test(text),
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
      for (let i = 0; i < 4; i++) {
        await clickText(cdp, /^(Zoom in|放大)$/);
        await sleep(400);
      }
      const hit = await clickText(cdp, /拔摩|Patmos/);
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

  // (c) The LEFT end at the same zoom, for comparison: this is where
  //     the lifelines are, and the ground under them is plain rather
  //     than hatched.
  notes.leftEnd = await capture('chrono-left', {
    width: 900, height: 1500,
    steps: async ({ cdp }) => {
      for (let i = 0; i < 4; i++) {
        await clickText(cdp, /^(Zoom in|放大)$/);
        await sleep(400);
      }
      await clickText(cdp, /^(创造|Creation)$/);
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

  for (const f of shots) console.log(`  captured ${f}`);
  console.log(`  reaches Revelation on screen: ${notes.overview.reachesRevelation}`);
  console.log(`  names the computed/placed boundary: ${notes.overview.namesBoundary}`);
  console.log(`  jump-to-Patmos worked: ${notes.rightEnd.clickedPatmos}, ` +
    `cursor lands on AD 95: ${notes.rightEnd.cursorAtRevelation}`);
  return { shots, ...notes };
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
    if (CMD === 'all' || CMD === 'youtube') out.youtube = await runYoutube(origin);
    if (CMD === 'all' || CMD === 'typography') out.typography = await runTypography(origin);
    if (CMD === 'all' || CMD === 'chronology') {
      out.chronology = await runChronology(origin);
    }
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
  for (const [label, s] of [['sermon', out.sermon],
                            ['sermon CONTROL', out.sermonControl]]) {
    if (!s) continue;
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
