#!/usr/bin/env node
// Offline tests for tools/check_video_ids.js's verdict logic.
//
//     node --test tools/check_video_ids.test.js
//
// The network half of that script cannot be tested without a network,
// but the half that matters — deciding whether a 403 is the video's
// problem or ours — is pure, and every branch of it is driven here.
// Without this, "403 means private" and "403 means we are throttled"
// would both be untested opinions.
'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const { judge, collectIds } = require('./check_video_ids.js');

const ok = (id) => ({ id, where: `s/e/${id}`, status: 200, title: 'T' });
const with403 = (id) => ({ id, where: `s/e/${id}`, status: 403 });
const with404 = (id) => ({ id, where: `s/e/${id}`, status: 404 });
const net = (id) => ({ id, where: `s/e/${id}`, status: 'network', error: 'ETIMEDOUT' });

/** n healthy results plus whatever else is passed. */
const batch = (n, ...rest) =>
  [...Array.from({ length: n }, (_, i) => ok(`good${i}`)), ...rest];

test('a lone 403 in a healthy batch is that video\'s problem', () => {
  const v = judge(batch(65, with403('QmTEkPquvcQ')));
  assert.equal(v.batchHealthy, true);
  assert.equal(v.failures.length, 1);
  assert.match(v.failures[0], /QmTEkPquvcQ/);
  assert.match(v.failures[0], /Do NOT delete the id/);
});

test('403s across the batch are OUR problem and never fail the run', () => {
  // Ten of sixty-six forbidden: this is what a rate-limited runner
  // looks like, and calling any of them "private" would be a lie.
  const v = judge(batch(56, ...Array.from({ length: 10 }, (_, i) => with403(`x${i}`))));
  assert.equal(v.batchHealthy, false);
  assert.deepEqual(v.failures, []);
  assert.equal(v.notes.length, 1);
  assert.match(v.notes[0], /INCONCLUSIVE/);
});

test('a 404 is definitive and fails even in an unhealthy batch', () => {
  const v = judge(batch(10, with404('deadid'), ...Array.from(
    { length: 20 }, (_, i) => with403(`x${i}`))));
  assert.equal(v.batchHealthy, false);
  assert.equal(v.failures.length, 1);
  assert.match(v.failures[0], /deadid/);
  assert.match(v.failures[0], /does not exist/);
});

test('an acknowledged 403 is a note, not a failure', () => {
  const known = { QmTEkPquvcQ: { since: '2026-09-05', note: 'church asked' } };
  const v = judge(batch(65, with403('QmTEkPquvcQ')), known);
  assert.deepEqual(v.failures, []);
  assert.equal(v.notes.length, 1);
  assert.match(v.notes[0], /still unavailable, known since 2026-09-05/);
});

test('an acknowledged id that plays again asks to be un-acknowledged', () => {
  const known = { comeback: { since: '2026-09-05' } };
  const v = judge(batch(65, ok('comeback')), known);
  assert.deepEqual(v.failures, []);
  assert.ok(v.notes.some((n) => /comeback plays again/.test(n)));
});

test('an acknowledged id no longer in videos.json asks to be removed', () => {
  const known = { ghost: { since: '2026-09-05' } };
  const v = judge(batch(66), known, new Set(['good0']));
  assert.ok(v.notes.some((n) => /ghost is acknowledged/.test(n)));
});

test('a network error is inconclusive, never a failure', () => {
  const v = judge(batch(65, net('flaky')));
  assert.deepEqual(v.failures, []);
  assert.ok(v.notes.some((n) => /flaky/.test(n) && /inconclusive/.test(n)));
});

test('an all-green batch says nothing at all', () => {
  const v = judge(batch(66));
  assert.deepEqual(v.failures, []);
  assert.deepEqual(v.notes, []);
});

test('collectIds walks the real videos.json and finds every track', () => {
  const doc = JSON.parse(
    require('fs').readFileSync(
      require('path').join(__dirname, '..', 'assets', 'videos.json'), 'utf8'));
  const ids = collectIds(doc);
  // Counted independently, by a walk that cares about nothing except
  // the key name. The first version of collectIds() knew about
  // series→episodes→tracks and so found 64 of 66 — it silently skipped
  // the two whole-series compilations and would have reported "all
  // clear" over them forever. This asserts the checker sees the whole
  // file, not the part of it someone remembered.
  const everyId = new Set();
  (function sweep(node) {
    if (Array.isArray(node)) return node.forEach(sweep);
    if (!node || typeof node !== 'object') return;
    for (const [k, v] of Object.entries(node)) {
      if (k === 'youtubeId' && typeof v === 'string') everyId.add(v);
      else sweep(v);
    }
  })(doc.series);
  assert.equal(ids.size, everyId.size,
    `collectIds found ${ids.size} of ${everyId.size} youtubeId values`);
  assert.ok(ids.size >= 60, `only found ${ids.size} ids`);
  // The two compilations are the ids the shape-aware version missed.
  assert.ok(ids.has('J8bBBHIuxjI'), 'the English whole-series compilation');
  assert.ok(ids.has('QXU-gazdgN0'), 'the Chinese whole-series compilation');
  for (const [id, where] of ids) {
    assert.match(id, /^[A-Za-z0-9_-]{11}$/, `${id} at ${where}`);
  }
  const series = new Set([...ids.values()].map((w) => w.split('/')[0]));
  assert.deepEqual(
    [...series].sort(),
    (doc.series || []).map((s) => s.id).sort(),
  );
});
