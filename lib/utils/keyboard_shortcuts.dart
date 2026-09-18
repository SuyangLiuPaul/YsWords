/// The keys the app answers to, as tables — 2026-09-18.
///
/// The reading column's keys (`[` `]` `/` `?`, the ⌘ set for a Mac, the
/// Ctrl set for Windows and Linux) were typed straight into its
/// `CallbackShortcuts`, and the `?` key opened a dialog that listed four
/// of the ten. The projection's keymap was an if-chain nobody could
/// read without the source.
///
/// 「……是不是应该有一个page教我们怎么用 words也是」. The Help page prints
/// the keys, so the keys live in a table that the widget builds its
/// bindings FROM and the Help page prints — one list read twice, which
/// is the only way the printed list stays true the first time somebody
/// adds a key. The projection's table lives with the projection
/// (`kProjectionKeymap`); the reading column's is here.
///
/// Flutter-free apart from the key constants and `SingleActivator`, so
/// every table can be asserted in a plain test.
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;

/// A key and the modifiers it needs, spelled the way `SingleActivator`
/// takes them — [meta] is ⌘ on a Mac and the Windows key elsewhere,
/// [control] is Ctrl everywhere. The reading column binds BOTH `⌘[` and
/// `Ctrl+[`, and a reader should be shown the one their keyboard means.
class KeyChord {
  const KeyChord(
    this.key, {
    this.meta = false,
    this.control = false,
    this.shift = false,
  });

  final LogicalKeyboardKey key;
  final bool meta;
  final bool control;
  final bool shift;

  SingleActivator get activator =>
      SingleActivator(key, meta: meta, control: control, shift: shift);

  /// Whether a reader on [apple] hardware should be SHOWN this chord.
  ///
  /// Every chord is bound on every platform; this only decides what the
  /// Help page prints. A ⌘ chord is the Windows key on a PC — it works,
  /// and nobody reaches for it — and a Ctrl chord on a Mac is the one
  /// the ⌘ row beside it already covers.
  bool shownOn({required bool apple}) {
    if (meta) return apple;
    if (control) return !apple;
    return true;
  }

  String label({required bool mac}) {
    // `?` is Shift+/ on every layout this app is read on; printing
    // "Shift+?" would describe a key nobody can find.
    final showShift = shift && key != LogicalKeyboardKey.question;
    final parts = <String>[
      if (meta) mac ? '⌘' : 'Win',
      if (control) mac ? '⌃' : 'Ctrl',
      if (showShift) mac ? '⇧' : 'Shift',
      keyCapLabel(key),
    ];
    return parts.join(mac ? '' : '+');
  }
}

/// How one key is printed on the Help page — a key cap, not a debug
/// name.
String keyCapLabel(LogicalKeyboardKey key) {
  final fixed = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.escape: 'Esc',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.backspace: '⌫',
    LogicalKeyboardKey.pageUp: 'PgUp',
    LogicalKeyboardKey.pageDown: 'PgDn',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.bracketLeft: '[',
    LogicalKeyboardKey.bracketRight: ']',
    LogicalKeyboardKey.slash: '/',
    LogicalKeyboardKey.question: '?',
    LogicalKeyboardKey.comma: ',',
    LogicalKeyboardKey.period: '.',
    // `=` is the key that prints `+`; see the projection's keymap.
    LogicalKeyboardKey.equal: '+',
    LogicalKeyboardKey.add: '+',
    LogicalKeyboardKey.numpadAdd: '+',
    LogicalKeyboardKey.minus: '−',
    LogicalKeyboardKey.numpadSubtract: '−',
  };
  final named = fixed[key];
  if (named != null) return named;
  final label = key.keyLabel;
  return label.isEmpty ? key.debugName ?? '?' : label.toUpperCase();
}

/// One row of a surface's key table: what it does, which key does it.
///
/// Generic over the surface's own action enum so the widget can switch
/// over its ids exhaustively — adding a row does not compile until the
/// widget answers it.
class BoundKey<T extends Enum> {
  const BoundKey(this.id, this.chord, this.labelKey);

  final T id;
  final KeyChord chord;

  /// The `ui_strings` key naming what it does.
  final String labelKey;
}

/// The reading column. Active while it has focus and no text field
/// does.
enum ReaderKey { previousChapter, nextChapter, search, help, settings }

const List<BoundKey<ReaderKey>> kReaderShortcuts = [
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft), 'previousChapter'),
  BoundKey(ReaderKey.nextChapter, KeyChord(LogicalKeyboardKey.bracketRight),
      'nextChapter'),
  BoundKey(ReaderKey.search, KeyChord(LogicalKeyboardKey.slash),
      'keySearchFromReader'),
  BoundKey(ReaderKey.help,
      KeyChord(LogicalKeyboardKey.question, shift: true), 'keyOpenHelp'),
  // ⌘ for a Mac and an iPad with a keyboard (2026-05-24, v1.3.17)…
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft, meta: true), 'previousChapter'),
  BoundKey(ReaderKey.nextChapter,
      KeyChord(LogicalKeyboardKey.bracketRight, meta: true), 'nextChapter'),
  BoundKey(ReaderKey.search, KeyChord(LogicalKeyboardKey.keyF, meta: true),
      'keySearchFromReader'),
  BoundKey(ReaderKey.settings, KeyChord(LogicalKeyboardKey.comma, meta: true),
      'settings'),
  // …and Ctrl for Windows and Linux, which have no ⌘. Deliberately no
  // Ctrl+F: that is the browser's find, and on a Mac it is line-start.
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft, control: true),
      'previousChapter'),
  BoundKey(ReaderKey.nextChapter,
      KeyChord(LogicalKeyboardKey.bracketRight, control: true), 'nextChapter'),
];
