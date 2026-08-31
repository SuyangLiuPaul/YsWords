#!/usr/bin/env node
// Headless-Chrome repro harness for the mailed-in boot crash — `Invalid
// argument: 0`, web release only (docs/autonomous-queue.md:110, "a boot
// crash the app cannot recover from on its own").
//
// This is step (a) named by the 2026-09-01 queue update: every VM-side
// avenue (test/boot_trap_shape_vm_repro_test.dart) is spent — 7 stale-value
// shapes through runBootstrapProper threw no ArgumentError. The one
// candidate left is web-only code (lib/services/url_sync_service_web.dart's
// _applyHashToState / _parseHash), gated `dart:js_interop` and unreachable
// from the VM harness. A browser is the missing tool, not a missing idea.
//
// What this does, against a real target origin (default: deployed dev):
//   1. Launch headless Chrome with a throwaway profile.
//   2. Load the origin once so localStorage exists for it.
//   3. Clear localStorage and plant EXACTLY the trap's three legacy keys
//      (flutter.book / flutter.chapter / flutter.version) — no profile.*
//      keys, matching the mailed-in report.
//   4. Reload with a chosen URL hash (bare `/`, a valid deep link, or a
//      stale one whose book/chapter/version disagree with the planted
//      keys — the one shape only `_applyHashToState` sees, since
//      `restoreState()` already ran before the hash is applied).
//   5. Capture window.onerror, unhandledrejection, console output and
//      CDP Runtime.exceptionThrown for ~15s, then report what happened.
//
// Zero dependencies: Node 24's built-in global `fetch` and `WebSocket`
// talk to Chrome's DevTools Protocol directly — no puppeteer, no
// node_modules, nothing added to this repo's dependency graph.
//
//     node tools/boot_trap_headless_repro.mjs [origin]
//
// Defaults to https://yswords-dev.netlify.app (dev only — never prod).
'use strict';

import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME =
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORT = 9333;
const ORIGIN = process.argv[2] || 'https://yswords-dev.netlify.app';

if (!/yswords-dev\.netlify\.app|yswords-qat\.netlify\.app|localhost|127\.0\.0\.1/.test(ORIGIN)) {
  console.error(`Refusing: ${ORIGIN} is not a recognised dev/qat/local origin. ` +
    'This harness plants localStorage and reloads — never point it at prod.');
  process.exit(2);
}

const PLANT_JOHN_3_KJV = { 'flutter.book': 'John', 'flutter.chapter': '3', 'flutter.version': 'kjv' };

// `expect` is what a CORRECT, fully-applied run should leave in the primary
// pane's storage (`flutter.book` / `flutter.chapter` / `flutter.version` —
// `_storagePrefix` is `''` for the primary pane, `main_provider.dart:60`,
// written by `saveCurrentState()` at `:1428-1430`). It is a claim about
// normal behaviour, verified per-shape against the actual asset JSON below
// (see the commit message / queue entry for the verification), NOT a
// root-cause claim about the crash. Shapes designed to fail validation
// midway (stale-disagreeing) get a `note` instead of a full `expect`,
// because `_applyHashToState`'s version-swap runs UNCONDITIONALLY before
// the `hasVerse` guard (`:259-271` vs `:282`), so only `version` is
// pinned down for those; `book`/`chapter` legitimately depend on whatever
// `restoreState()` produced before the hash was applied, which this
// harness does not independently pre-compute.
const TRAP_SHAPES = [
  {
    name: 'bare-hash (#/ / no hash at all)',
    hash: '',
    plant: PLANT_JOHN_3_KJV,
    expect: { book: 'John', chapter: '3', version: 'kjv' },
    note: 'empty hash: _parseHash returns null on the h.isEmpty check ' +
      '(:340), _applyHashToState never runs at all — landed state is ' +
      'exactly what restoreState() read from the planted keys.',
  },
  {
    name: 'valid-deep-link matching planted state',
    hash: '#/john/3:16?v=kjv',
    plant: PLANT_JOHN_3_KJV,
    expect: { book: 'John', chapter: '3', version: 'kjv' },
    note: 'hash matches the plant; John 3 has 36 verses in kjv (verified ' +
      'against assets/kjv.json) so verse 16 exists — this should fully ' +
      'apply, including the verse-jump index math at :307-311.',
  },
  {
    name: 'stale deep link DISAGREEING with planted state ' +
          '(the shape only _applyHashToState alone sees)',
    hash: '#/revelation/999:1?v=biblexg-v2',
    plant: PLANT_JOHN_3_KJV,
    expect: { version: 'biblexg-v2' },
    note: 'version swap runs unconditionally before the hasVerse guard ' +
      '(:259-271 vs :282); chapter 999 does not exist for 启示录 in any ' +
      'version (Revelation has 22 chapters), so hasVerse fails and ' +
      'book/chapter are left at whatever restoreState() produced BEFORE ' +
      'this hash was applied — not necessarily the planted John/3. Only ' +
      '`version` is checked for this shape; a book/chapter mismatch here ' +
      'is expected, not a finding.',
  },
  {
    name: 'stale verse, valid chapter — untried shape (b): reaches ' +
          'setCurrentChapter + the relIdx verse-jump math',
    hash: '#/john/3:999?v=kjv',
    plant: PLANT_JOHN_3_KJV,
    expect: { book: 'John', chapter: '3', version: 'kjv' },
    note: 'John 3 exists in kjv (36 verses, verified against ' +
      'assets/kjv.json; verse 999 does not) so hasVerse passes at :282 ' +
      'and mp.setCurrentChapter runs at :288 — the one line every prior ' +
      'pass\'s shapes never reached. The verse lookup at :307-311 finds ' +
      'no match (relIdx == -1) and is skipped by the `if (relIdx >= 0)` ' +
      'guard, so no verse jump; landed chapter should still be 3.',
  },
  {
    name: 'cross-version cross-language deep link — heaviest untried ' +
          'path: version swap + FetchBooks + book-name translation mid-boot',
    hash: '#/revelation/17:1?v=biblexg-v2',
    plant: PLANT_JOHN_3_KJV,
    expect: { book: '启示录', chapter: '17', version: 'biblexg-v2' },
    note: 'Revelation 17 has 18 verses in biblexg-v2 (book field 启示录, ' +
      'verified against assets/biblexg-v2.json); englishToChinese maps ' +
      '"Revelation"->"启示录" (book_name_mapping.dart:70), so ' +
      'translateBookName resolves it correctly if the version-swap + ' +
      'FetchBooks sequence at :259-271 completes before the translation ' +
      'at :278 runs. This exact link is named in the :249-258 code ' +
      'comment as the historical v1.3.61 bug case (cold boot to biblexg-v2 ' +
      'while default-booted in an English version) — the fix for THAT bug ' +
      'is what this shape re-exercises end to end.',
  },
];

function waitFor(predicate, timeoutMs, intervalMs = 200) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    const tick = async () => {
      let ok;
      try {
        ok = await predicate();
      } catch {
        ok = false;
      }
      if (ok) return resolve();
      if (Date.now() - start > timeoutMs) {
        return reject(new Error('timed out waiting'));
      }
      setTimeout(tick, intervalMs);
    };
    tick();
  });
}

async function cdpVersion() {
  const res = await fetch(`http://127.0.0.1:${PORT}/json/version`);
  if (!res.ok) throw new Error(`status ${res.status}`);
  return res.json();
}

async function newTab(url) {
  const res = await fetch(
    `http://127.0.0.1:${PORT}/json/new?${encodeURIComponent(url)}`,
    { method: 'PUT' },
  );
  if (!res.ok) throw new Error(`/json/new failed: ${res.status}`);
  return res.json();
}

async function closeTab(id) {
  await fetch(`http://127.0.0.1:${PORT}/json/close/${id}`).catch(() => {});
}

class Cdp {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = [];
    this.ready = new Promise((resolve, reject) => {
      this.ws.addEventListener('open', () => resolve());
      this.ws.addEventListener('error', (e) => reject(e));
    });
    this.ws.addEventListener('message', (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(JSON.stringify(msg.error)));
        else resolve(msg.result);
      } else if (msg.method) {
        for (const l of this.listeners) l(msg.method, msg.params);
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

  on(fn) {
    this.listeners.push(fn);
  }

  close() {
    this.ws.close();
  }
}

async function runShape(shape) {
  console.log(`\n=== ${shape.name} ===`);
  console.log(`    hash: ${JSON.stringify(shape.hash) || '(empty)'}`);
  console.log(`    planted keys: ${JSON.stringify(shape.plant)}`);

  const tab = await newTab('about:blank');
  const cdp = new Cdp(tab.webSocketDebuggerUrl);
  await cdp.ready;

  const events = [];
  cdp.on((method, params) => {
    if (method === 'Runtime.exceptionThrown') {
      const d = params.exceptionDetails;
      events.push({
        kind: 'Runtime.exceptionThrown',
        text: d.text,
        message: d.exception?.description || d.exception?.value,
        url: d.url,
        line: d.lineNumber,
        col: d.columnNumber,
        stack: d.stackTrace,
      });
    } else if (method === 'Runtime.consoleAPICalled') {
      // Capture every console call regardless of type. Flutter web release
      // does not strip debugPrint, so the boot-failure prints this repro
      // exists to see (url_sync_service_web.dart's "[UrlSync] boot apply
      // failed", main.dart's "Bootstrap failed at ...") arrive as ordinary
      // console.log, not console.error — filtering at capture time would
      // silently discard exactly the evidence this harness is for.
      const args = (params.args || [])
        .map((a) => a.value ?? a.description ?? '')
        .join(' ');
      events.push({ kind: `console.${params.type}`, text: args });
    }
  });

  // Network oracle (secondary, meaningful once Part 1 — the ErrorReporter
  // calls added to url_sync_service_web.dart's two catches — is deployed
  // to ORIGIN). A swallowed `_applyHashToState` throw now becomes a real
  // outbound POST to /api/errorReport instead of a silent debugPrint. This
  // is best-effort: `request.postData` is only populated on
  // requestWillBeSent when CDP captured it inline; if it's missing we try
  // `Network.getRequestPostData` once, and if that also comes up empty we
  // still record that the POST happened.
  const errorReportRequests = [];
  cdp.on((method, params) => {
    if (method !== 'Network.requestWillBeSent') return;
    const url = params.request?.url || '';
    if (!url.includes('/api/errorReport')) return;
    errorReportRequests.push({
      requestId: params.requestId,
      url,
      postData: params.request?.postData || null,
    });
  });

  await cdp.send('Runtime.enable');
  await cdp.send('Page.enable');
  await cdp.send('Network.enable');

  // Inject BEFORE any page script runs, on every document (so it survives
  // the reload after planting storage) — mirrors what a real browser
  // console would show for window.onerror / unhandledrejection, which CDP
  // does not surface as Runtime.exceptionThrown by default for onerror
  // handlers that swallow the event.
  await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
    source: `
      window.addEventListener('error', function(e) {
        console.error('BOOT_TRAP window.onerror: ' + e.message +
          ' @ ' + e.filename + ':' + e.lineno + ':' + e.colno);
      });
      window.addEventListener('unhandledrejection', function(e) {
        var r = e.reason;
        console.error('BOOT_TRAP unhandledrejection: ' +
          (r && r.stack ? r.stack : String(r)));
      });
    `,
  });

  // 1. Load the bare origin first so localStorage exists for it.
  await cdp.send('Page.navigate', { url: ORIGIN + '/' });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 15000).catch(() => {
    console.log('    (warning: initial load did not reach readyState=complete in 15s)');
  });

  // 2. Clear storage, plant exactly the trap's keys.
  const plantExpr = `
    (function() {
      localStorage.clear();
      var plant = ${JSON.stringify(shape.plant)};
      for (var k in plant) localStorage.setItem(k, plant[k]);
      return Object.keys(localStorage).sort();
    })()
  `;
  const plantResult = await cdp.send('Runtime.evaluate', {
    expression: plantExpr,
    returnByValue: true,
  });
  console.log(`    localStorage after planting: ${JSON.stringify(plantResult.result?.value)}`);

  // 3. Reload with the chosen hash present at load time (hash must be
  // part of the navigated URL — captureBootHash() in main.dart runs
  // synchronously before runApp, so setting location.hash after load
  // would miss it). A same-origin navigation that differs from the
  // current URL only in the fragment is a same-document navigation in
  // Chrome — no reload, no main(), no captureBootHash() — so bounce
  // through about:blank first to force a real document load. Same-origin
  // localStorage survives this because it's origin-scoped, not
  // document-scoped.
  await cdp.send('Page.navigate', { url: 'about:blank' });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 5000).catch(() => {});

  const timeOriginBefore = await cdp.send('Runtime.evaluate', {
    expression: 'performance.timeOrigin',
  }).then((r) => r.result?.value).catch(() => null);

  const targetUrl = ORIGIN + '/' + shape.hash;
  await cdp.send('Page.navigate', { url: targetUrl });
  await waitFor(async () => {
    const r = await cdp.send('Runtime.evaluate', {
      expression: 'document.readyState',
    });
    return r.result?.value === 'complete';
  }, 15000).catch(() => {
    console.log('    (warning: target load did not reach readyState=complete in 15s)');
  });

  // Confirm the boot actually re-ran: a same-document navigation would
  // have a stale (unset) or unchanged performance.timeOrigin; a real
  // load gives the new document a fresh one.
  const timeOriginAfter = await cdp.send('Runtime.evaluate', {
    expression: 'performance.timeOrigin',
  }).then((r) => r.result?.value).catch(() => null);
  console.log(`    fresh document load confirmed: ` +
    `${timeOriginBefore != null && timeOriginAfter != null && timeOriginAfter !== timeOriginBefore} ` +
    `(timeOrigin ${timeOriginBefore} -> ${timeOriginAfter})`);

  // 4. Give the bundle time to boot and (maybe) crash. The mitigation
  // path is a 45s auto-recovery timer; this window is longer than the
  // minimum needed on purpose — long enough to distinguish "the engine
  // never painted" from "still loading", short of the 45s recovery
  // timer so it doesn't mask a pre-mitigation cold-boot throw.
  await new Promise((r) => setTimeout(r, 15000));

  const finalState = await cdp.send('Runtime.evaluate', {
    expression: `
      (function() {
        var el = document.getElementById('ys-boot');
        // <flt-glass-pane> is the shadow host Flutter web's engine
        // creates once it has actually painted a frame — a more
        // reliable "did it boot" signal than innerText, which stays
        // empty even on a healthy boot because Flutter renders to
        // canvas/DOM nodes that document.body.innerText does not walk.
        var glassPane = document.querySelector('flt-glass-pane');
        // State oracle: dump every key/VALUE, not just key names. The
        // primary reading pane's _storagePrefix is '' (main_provider.dart
        // :60), so book/chapter/version live at the unscoped
        // flutter.book / flutter.chapter / flutter.version keys written by
        // saveCurrentState() (:1428-1430). Reading the values (not just
        // presence) is what lets this harness tell "landed where the hash
        // pointed" from "landed where the trap planted it and the apply
        // silently no-op'd" — the shape a swallowed throw produces.
        var kv = {};
        Object.keys(localStorage).sort().forEach(function(k) {
          kv[k] = localStorage.getItem(k);
        });
        return {
          bootSplashPresent: !!el,
          glassPanePresent: !!glassPane,
          bodyTextSnippet: (document.body.innerText || '').slice(0, 300),
          localStorage: kv,
          landed: {
            book: localStorage.getItem('flutter.book'),
            chapter: localStorage.getItem('flutter.chapter'),
            version: localStorage.getItem('flutter.version'),
          },
        };
      })()
    `,
    returnByValue: true,
  }).catch((e) => ({ result: { value: { error: String(e) } } }));

  // Resolve any /api/errorReport POST bodies CDP didn't inline. Best
  // effort — by now the request has long finished, so a miss here just
  // means "POST happened, body unavailable", not "no POST happened".
  for (const req of errorReportRequests) {
    if (req.postData) continue;
    try {
      const r = await cdp.send('Network.getRequestPostData', { requestId: req.requestId });
      req.postData = r?.postData || null;
    } catch {
      /* body not retrievable after the fact — leave null */
    }
  }
  if (errorReportRequests.length > 0) {
    console.log(`    /api/errorReport POSTs observed: ${errorReportRequests.length}`);
    for (const req of errorReportRequests) {
      console.log(`      -> ${req.url}`);
      console.log(`         body: ${req.postData || '(unavailable)'}`);
    }
  } else {
    console.log('    /api/errorReport POSTs observed: 0');
  }

  const landed = finalState.result?.value?.landed;
  if (shape.expect && landed) {
    const mismatches = Object.entries(shape.expect)
      .filter(([k, v]) => landed[k] !== v)
      .map(([k, v]) => `${k}: expected ${JSON.stringify(v)}, landed ${JSON.stringify(landed[k])}`);
    if (mismatches.length === 0) {
      console.log(`    state oracle: MATCHES expected landing (${JSON.stringify(shape.expect)})`);
    } else {
      console.log(`    state oracle: MISMATCH — ${mismatches.join('; ')}`);
      console.log('      (a mismatch here means the hash did not fully apply — ' +
        'consistent with, though not proof of, a swallowed throw)');
    }
  } else if (shape.expect) {
    console.log('    state oracle: could not read landed state (see finalState.error below)');
  }

  console.log(`    events captured: ${events.length}`);
  for (const e of events) {
    console.log(`      [${e.kind}] ${e.text || e.message}` +
      (e.url ? ` (${e.url}:${e.line}:${e.col})` : ''));
    if (e.stack?.callFrames?.length) {
      for (const f of e.stack.callFrames.slice(0, 5)) {
        console.log(`          at ${f.functionName || '(anonymous)'} ` +
          `${f.url}:${f.lineNumber}:${f.columnNumber}`);
      }
    }
  }
  console.log(`    final page state: ${JSON.stringify(finalState.result?.value)}`);

  cdp.close();
  await closeTab(tab.id);

  return {
    shape: shape.name,
    events,
    finalState: finalState.result?.value,
    errorReportRequests,
  };
}

async function main() {
  const userDataDir = mkdtempSync(join(tmpdir(), 'ys-boot-trap-repro-'));
  console.log(`Launching headless Chrome (profile: ${userDataDir}) against ${ORIGIN}`);

  const chrome = spawn(CHROME, [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-extensions',
  ], { stdio: 'ignore' });

  const cleanup = () => {
    try { chrome.kill(); } catch {}
    try { rmSync(userDataDir, { recursive: true, force: true }); } catch {}
  };
  process.on('exit', cleanup);
  process.on('SIGINT', () => { cleanup(); process.exit(130); });

  try {
    await waitFor(() => cdpVersion().then(() => true), 10000);
  } catch (e) {
    console.error('Chrome did not come up on the debug port in 10s:', e.message);
    process.exitCode = 2;
    return;
  }

  const results = [];
  for (const shape of TRAP_SHAPES) {
    try {
      results.push(await runShape(shape));
    } catch (e) {
      console.error(`  FAILED to run shape "${shape.name}": ${e.stack || e}`);
      results.push({ shape: shape.name, error: String(e) });
    }
  }

  console.log('\n=== summary ===');
  let anyThrow = false;
  let anyErrorReport = false;
  for (const r of results) {
    const throwCount = (r.events || []).filter(
      (e) => e.kind === 'Runtime.exceptionThrown' ||
             /BOOT_TRAP window\.onerror|BOOT_TRAP unhandledrejection/i.test(e.text || ''),
    ).length;
    if (throwCount > 0) anyThrow = true;
    const reportCount = (r.errorReportRequests || []).length;
    if (reportCount > 0) anyErrorReport = true;
    console.log(`  ${r.shape}: ${throwCount} throw-like event(s), ` +
      `${reportCount} /api/errorReport POST(s)` +
      (r.error ? ` (harness error: ${r.error})` : ''));
  }
  // The network oracle is the primary signal once Part 1 is deployed: a
  // swallowed _applyHashToState throw now reaches ErrorReporter.report
  // (source: 'UrlSync.boot' / 'UrlSync.popstate'), which POSTs here even
  // though debugPrint stays silent in release web. The console/CDP
  // exception oracle from prior passes is kept as a secondary signal —
  // it catches anything that escapes the local catch entirely.
  if (anyErrorReport) {
    console.log('\n/api/errorReport fired on at least one shape — that IS ' +
      'the throw site this item has been looking for (see the POST ' +
      'bodies logged per-shape above for the error string + stack). Do ' +
      'not state a root cause beyond what that body actually says.');
  } else if (anyThrow) {
    console.log('\nAt least one shape produced a throw/rejection outside ' +
      'the local catch (CDP exception or window.onerror/unhandledrejection) ' +
      '— see events above for the frame. Do NOT state a root cause without ' +
      'decoding it against a matching --source-maps build; report only ' +
      'what was observed here.');
  } else {
    console.log('\nNo shape produced an /api/errorReport POST or an ' +
      'uncaught throw/rejection in the ~15s observation window. This ' +
      'clears exactly the shapes tried, on ORIGIN as deployed at run ' +
      'time — check the per-shape "state oracle" lines above: a MATCH ' +
      'means the hash fully applied (clean, not just quiet); a ' +
      'MISMATCH without a POST is itself new information (the apply did ' +
      'not complete AND nothing reported why) and should be written up, ' +
      'not treated as "no throw".');
  }
}

main();
