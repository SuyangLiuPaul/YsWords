import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression test for "on the Bible reader, Back pushes a route instead
/// of popping" (docs/autonomous-queue.md, fixed 2026-09-05).
///
/// **What was wrong.** `url_sync_service_web.dart`'s `_writeStateToUrl`
/// wrote the reader's shareable hash with
/// `window.history.pushState(null, '', newHash)`. A `null` state is
/// neither of the two tags the Flutter web engine puts on the entries it
/// owns (`{'origin': true}` and `{'flutter': true}`), so every chapter
/// turn left a foreign entry sitting on top of the engine's own — the
/// exact shape `SingleEntryBrowserHistory.onPopState`'s last branch is
/// written to RECOVER from, its comment being "The user has pushed a new
/// entry on top of our flutter entry… when the user modifies the hash
/// part of the url directly".
///
/// Measured in headless Chrome against a real release bundle (v1.4.214),
/// cold-loading `/#/micah/2?v=kjv`, tapping Next Chapter twice and
/// pressing Back ONCE:
///
///     popstate     #/micah/3:1?v=kjv     state=null
///     popstate     #/micah/2?v=kjv       state=null
///     popstate     #/HomePage            state={"flutter":true}
///     replaceState /#/_unknown           state={"flutter":true}
///     pushState    #/micah/2?v=kjv       state=null
///
/// Three popstates and `currentIndex` down by three for one Back; the
/// engine's recovery walk ended in a `pushRoute`, GetX had no registered
/// name for `/micah/2?v=kjv`, and so a press of Back PUSHED
/// `unknownRoute` onto the Navigator. The forward entries were then
/// discarded by the 350 ms correction pushing from a non-tip entry.
///
/// **Why this file is a source-shape check and not a widget test.** The
/// code under test is behind `dart:js_interop` and is not reachable from
/// the VM harness at all — `flutter test` cannot import it, cannot mock
/// `window.history`, and cannot deliver a `popstate`. The same reasoning
/// is already written down in `test/web_back_single_entry_history_test.
/// dart`'s third case, which guards the previous fix in this file the
/// same way. The end-to-end proof is
/// `tools/web_verify_headless.mjs bible`, which drives a real release
/// build in a real browser and exits 1 on the old behaviour.
///
/// So what this file buys is narrow and worth stating plainly: it cannot
/// prove Back pops, and it does not claim to. It fails the moment the
/// raw push comes back — by an edit, a merge, or a revert — which is the
/// failure mode that actually threatens this fix, because the browser
/// gate needs a release build and does not run on every change.
void main() {
  final webImpl =
      File('lib/services/url_sync_service_web.dart').readAsStringSync();

  test('the reader\'s URL write REPLACES the current history entry', () {
    expect(
      webImpl,
      contains("_window.history.replaceState(_window.history.state, '', newHash)"),
      reason: 'the reader\'s state->URL write must replace the current '
          'entry, and must pass the EXISTING state object back so the '
          'engine\'s own {origin:true}/{flutter:true} tag survives. If '
          'this line has moved or been reshaped, re-run '
          '`node tools/web_verify_headless.mjs bible` against a release '
          'build before changing this expectation.',
    );
  });

  test('nothing in the web URL layer calls history.pushState', () {
    expect(
      webImpl,
      isNot(contains('history.pushState')),
      reason: 'a raw pushState here creates a browser history entry the '
          'Flutter web engine does not recognise. Measured consequence '
          'of one such entry: ONE Back produced three popstate events, '
          'walked past every chapter, pushed GetX\'s unknownRoute page '
          'and discarded three forward entries. Note this is wrong under '
          'the OTHER history mode too — '
          'MultiEntriesBrowserHistory.onPopState serial-tags an '
          'unrecognised entry and dispatches pushRouteInformation — so '
          'the pending GetMaterialApp.router migration is not a reason '
          'to put it back.',
    );
  });

  test('the pushState interop binding is not declared at all', () {
    // Deliberately stronger than "is not called". The binding is one
    // line of `external` boilerplate; leaving it declared makes
    // reintroducing the defect a matter of typing `push` and accepting
    // a completion.
    expect(
      webImpl,
      isNot(contains('external void pushState')),
      reason: 'the JS interop shim should not offer pushState at all — '
          'see the comment on the _History extension',
    );
    expect(
      webImpl,
      contains('external void replaceState'),
      reason: 'the replace binding is the one the writer needs',
    );
    expect(
      webImpl,
      contains('external JSAny? get state'),
      reason: 'reading the current state back is what preserves the '
          'engine\'s entry tag; without it the writer would have to '
          'hardcode the engine\'s private tag names',
    );
  });

  test('the facade header no longer claims Back walks between chapters',
      () {
    // The claim was measured false on 2026-09-05 (see the trace in this
    // file's own doc comment) and corrected in the same pass. It read
    // plausibly for months, which is exactly why it is pinned here: a
    // comment nobody tests drifts back.
    final facade =
        File('lib/services/url_sync_service.dart').readAsStringSync();
    expect(
      facade,
      isNot(contains('back / forward navigates between chapters')),
      reason: 'browser Back has never navigated between chapters in this '
          'app, and Forward is unreachable in single-entry history mode. '
          'Both were measured, not argued.',
    );
  });
}
