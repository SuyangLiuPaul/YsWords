import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/version_picker_sheet.dart';

/// 2026-09-06: the version picker, driven the way assistive technology
/// drives it.
///
/// `test/version_picker_sheet_test.dart` already taps the picker with
/// `tester.tap`, which hit-tests the RENDER tree. That is not the path a
/// screen reader takes, and it is not the path Flutter web takes once the
/// accessibility tree is on: both go through
/// `SemanticsOwner.performAction(nodeId, SemanticsAction.tap)` against a
/// node in the SEMANTICS tree. Those two trees disagreed here.
///
/// Every version of `PopupMenuItem` wraps its child in `MergeSemantics`
/// (`material/popup_menu.dart`, `PopupMenuItemState.build`), and the
/// picker hangs its whole body — three language pills and every version
/// row — inside ONE item. So the semantics tree held a single node
///
///     #9 rect=320x143 actions=focus|tap
///        label="English | 繁體中文 | 简体中文 | 和合本雅伟版(简体) | 梁家铿译本(简体)"
///          #10..#14 isMergedIntoParent=true   (the pills and the rows)
///
/// with all five real targets marked `isMergedIntoParent`. Activating it —
/// which is all a reader using VoiceOver, Switch Control or Voice Control
/// can do, and what a click anywhere over that rect does on web — ran the
/// FIRST language pill, whatever had been aimed at. Measured 5/5 on the
/// unfixed build: each of the five targets, tapped through the semantics
/// tree, switched to English and left the menu open. The Bible version was
/// unreachable for those readers.
///
/// These tests are written against `performAction`, not `tester.tap`, on
/// purpose: with `tester.tap` every case below passes while the feature is
/// completely broken.
void main() {
  const pillLabels = <String>['English', '繁體中文', '简体中文'];
  const simplified = <String>['和合本雅伟版(简体)', '梁家铿译本(简体)'];
  const traditional = <String>['和合本雅偉版(繁體)', '梁家鏗譯本(繁體)'];
  const english = <String>['King James Version', 'Lexham English Bible'];

  /// Opens the picker and returns a handle on it. `picked` / `closed` are
  /// filled in when the menu's future completes.
  Future<_Picker> open(
    WidgetTester tester, {
    String currentVersion = 'cuvs-yhwh',
    Size size = const Size(390, 844),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = AppSettings(); // defaults to zh-Hans locale
    final picker = _Picker(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showLanguageGroupedVersionMenu(
                    context: ctx,
                    position: const RelativeRect.fromLTRB(120, 200, 80, 0),
                    currentVersion: currentVersion,
                    settings: settings,
                  ).then((v) {
                    picker.picked = v;
                    picker.closed = true;
                  });
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picker;
  }

  testWidgets('every pill and every row is its own accessibility node',
      (tester) async {
    final handle = tester.ensureSemantics();
    final picker = await open(tester);

    // The defect, stated as the property that failed: none of the five
    // targets may be merged away, and each must carry its own tap action
    // on its own rect.
    final seen = <String, Rect>{};
    for (final label in [...pillLabels, ...simplified]) {
      final node = picker.nodeFor(label);
      expect(node, isNotNull, reason: '"$label" has no semantics node');
      expect(node!.isMergedIntoParent, isFalse,
          reason: '"$label" is merged into an ancestor — assistive '
              'technology cannot address it');
      expect(picker.headOf(node), label,
          reason: '"$label" shares a node with something else');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
          reason: '"$label" carries no tap action');
      seen[label] = node.rect;
    }
    // Five distinct rects, not one rect five times. Before the fix all
    // five collapsed into the single 320x143 body rect.
    expect(seen.values.map((r) => '${r.width}x${r.height}').toSet().length,
        greaterThan(1));
    expect(picker.bodyNode().getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'the menu item itself must not swallow the taps meant for '
            'the pills and rows');
    handle.dispose();
  });

  testWidgets('an accessibility tap on a version row picks THAT row',
      (tester) async {
    final handle = tester.ensureSemantics();
    final picker = await open(tester);
    picker.semanticTap('梁家铿译本(简体)');
    await tester.pumpAndSettle();
    expect(picker.closed, isTrue, reason: 'the menu did not close');
    expect(picker.picked, 'biblexg-v2');
    handle.dispose();
  });

  testWidgets('an accessibility tap on the CURRENT row closes with null',
      (tester) async {
    final handle = tester.ensureSemantics();
    final picker = await open(tester);
    picker.semanticTap('和合本雅伟版(简体)');
    await tester.pumpAndSettle();
    expect(picker.closed, isTrue);
    expect(picker.picked, isNull);
    handle.dispose();
  });

  testWidgets('an accessibility tap on each pill swaps to THAT language',
      (tester) async {
    final handle = tester.ensureSemantics();
    final picker = await open(tester);

    // English is pill 0 — the one the merged node always fired, so it is
    // the one case that would have "passed" for the wrong reason. It is
    // checked last, after two pills that the broken build could never
    // have reached.
    picker.semanticTap('繁體中文');
    await tester.pumpAndSettle();
    for (final t in traditional) {
      expect(find.text(t), findsOneWidget, reason: 'pill 繁體中文 -> $t');
    }
    expect(picker.closed, isFalse);

    picker.semanticTap('简体中文');
    await tester.pumpAndSettle();
    for (final t in simplified) {
      expect(find.text(t), findsOneWidget, reason: 'pill 简体中文 -> $t');
    }

    picker.semanticTap('English');
    await tester.pumpAndSettle();
    for (final t in english) {
      expect(find.text(t), findsOneWidget, reason: 'pill English -> $t');
    }
    expect(picker.closed, isFalse);
    handle.dispose();
  });

  testWidgets('a row reached through a pill still picks that row',
      (tester) async {
    // The two-step journey a reader actually makes: switch language, then
    // choose. Nothing below the first pill tap was reachable before.
    final handle = tester.ensureSemantics();
    final picker = await open(tester);
    picker.semanticTap('繁體中文');
    await tester.pumpAndSettle();
    picker.semanticTap('梁家鏗譯本(繁體)');
    await tester.pumpAndSettle();
    expect(picker.closed, isTrue);
    expect(picker.picked, 'biblexg-v2-tr');
    handle.dispose();
  });

  testWidgets('a row whose label carries an edition year is addressable too',
      (tester) async {
    // The English editions are the only rows with a non-empty
    // `editionYear`, so their node's label is TWO lines
    // ("King James Version\n1611 / 1769 revision"). A lookup keyed on the
    // whole label finds the three Chinese rows and silently loses both
    // English ones — which is exactly the mistake the browser harness made
    // on its first pass, and it would have left this half of the picker
    // unproven. Tap one through the semantics tree.
    final handle = tester.ensureSemantics();
    final picker = await open(tester);
    picker.semanticTap('English');
    await tester.pumpAndSettle();
    final kjv = picker.nodeFor('King James Version');
    expect(kjv, isNotNull);
    expect(kjv!.getSemanticsData().label, contains('1611'),
        reason: 'this is the two-line case; if the edition year is gone the '
            'test is no longer testing what it says it is');
    expect(kjv.isMergedIntoParent, isFalse);
    picker.semanticTap('King James Version');
    await tester.pumpAndSettle();
    expect(picker.closed, isTrue);
    expect(picker.picked, 'kjv');
    handle.dispose();
  });

  testWidgets('the picker keeps the metrics the owner signed off',
      (tester) async {
    // The fix removes a `MergeSemantics` — a `RenderProxyBox` whose only
    // override is `describeSemanticsConfiguration`
    // (`rendering/proxy_box.dart:4379`) — so no geometry may move. These
    // are the numbers measured off the tree BEFORE the change, at 390x844
    // with `cuvs-yhwh` current:
    //   popup frame   320 x 159
    //   body          320 x 143   (= 64 pill block + 1 divider + 2 x 39)
    //   language pill  96 x  48   (x3)
    //   version row   320 x  39   (x2)
    // If a later change to the picker moves any of them, the owner should
    // hear it from this test and not from the app.
    final handle = tester.ensureSemantics();
    final picker = await open(tester);
    expect(picker.nodeFor('Popup menu')!.rect.size, const Size(320, 159));
    expect(picker.bodyNode().rect.size, const Size(320, 143));
    for (final p in pillLabels) {
      expect(picker.nodeFor(p)!.rect.size, const Size(96, 48), reason: p);
    }
    for (final v in simplified) {
      expect(picker.nodeFor(v)!.rect.size, const Size(320, 39), reason: v);
    }
    handle.dispose();
  });
}

class _Picker {
  _Picker(this.tester);

  final WidgetTester tester;
  String? picked;
  bool closed = false;

  /// The live [SemanticsOwner], reached through the public
  /// [SemanticsController] rather than the deprecated
  /// `WidgetTester.binding.pipelineOwner`.
  SemanticsOwner get _owner =>
      tester.semantics.find(find.byType(MaterialApp)).owner!;

  List<SemanticsNode> _flatten(SemanticsNode n) {
    final out = <SemanticsNode>[n];
    n.visitChildren((c) {
      out.addAll(_flatten(c));
      return true;
    });
    return out;
  }

  /// A node's first label line. The English editions carry their
  /// `editionYear` on a second line, so the whole label is not the
  /// identity of the row.
  String headOf(SemanticsNode n) =>
      n.getSemanticsData().label.split('\n').first.trim();

  /// Finds by FIRST LINE, so this resolves a row with an edition year as
  /// well as one without. On the merged tree the picker's one node has
  /// "English" as its first line, so this deliberately keeps finding
  /// something there — the tests above are what tell the two trees apart,
  /// by that node's rect, its tap action and what activating it does.
  SemanticsNode? nodeFor(String label) {
    for (final n in _flatten(_owner.rootSemanticsNode!)) {
      if (headOf(n) == label) return n;
    }
    return null;
  }

  /// The node the picker's single `PopupMenuItem` produces — the one that
  /// used to carry the whole body's label and its tap action. Found as
  /// the direct PARENT of a version row, which is the same node before
  /// and after the fix (a merged child is still a child of the node it
  /// merges into).
  SemanticsNode bodyNode() {
    // Exactly the row's own label, so this finds the row's own node in
    // both trees — the merged one, where an ancestor's label CONTAINS
    // this string among four others, and the fixed one.
    final row = _flatten(_owner.rootSemanticsNode!)
        .firstWhere((n) => n.getSemanticsData().label == '和合本雅伟版(简体)');
    for (final n in _flatten(_owner.rootSemanticsNode!)) {
      var hit = false;
      n.visitChildren((c) {
        if (identical(c, row)) hit = true;
        return true;
      });
      if (hit) return n;
    }
    throw StateError('the version row has no parent semantics node');
  }

  /// Exactly what a screen reader (and Flutter web's DOM overlay) does.
  ///
  /// The id must be the one the PLATFORM was given, not the framework's.
  /// A node with `isMergedIntoParent` is never sent to the engine — its
  /// data is folded into the nearest ancestor that is — so the walk up
  /// here is not a convenience, it is the whole difference between this
  /// test and one that passes on a broken build. (`SemanticsController.find`
  /// resolves the same way, and for the same reason.)
  void semanticTap(String label) {
    var node = nodeFor(label);
    if (node == null) {
      throw StateError('no semantics node labelled "$label"');
    }
    while (node!.isMergedIntoParent && node.parent != null) {
      node = node.parent;
    }
    _owner.performAction(node.id, SemanticsAction.tap);
  }
}
