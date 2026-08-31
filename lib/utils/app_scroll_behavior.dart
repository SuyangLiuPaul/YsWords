import 'package:flutter/material.dart';

/// App-wide scroll feel.
///
/// 2026-08-03 (v1.4.5): scroll physics used to be set per-widget, so only
/// 6 of the ~27 files with lists actually opted into
/// [BouncingScrollPhysics]. Everything else fell through to the platform
/// default — meaning a list bounced on iOS but hard-stopped with a glow on
/// Android/web, and the app felt different depending on which screen you
/// were on. Setting the physics on the app's [ScrollBehavior] applies it
/// to EVERY scrollable at once (an explicit `physics:` on an individual
/// widget still wins, which is how the reading pane keeps its
/// `PageScrollPhysics` chapter-swipe).
///
/// Deliberate choices:
/// * `AlwaysScrollableScrollPhysics` parent — short lists still rubber-band
///   instead of feeling dead, which is most of the "premium" impression.
/// * Overscroll glow removed — the Android glow reads as a second, competing
///   overscroll affordance once the list already bounces.
/// * `dragDevices` left at the framework default ON PURPOSE. Adding
///   `PointerDeviceKind.mouse` would let a mouse drag-scroll, but it also
///   hijacks click-drag from text selection — this is a Bible reader, so
///   selecting verse text with the mouse matters more than drag-scrolling.
/// Physics for the scrollable that [EditableText] builds *inside* every
/// [SelectableText] — pass it as `scrollPhysics:` at every call site.
///
/// 2026-08-31: [AppScrollBehavior] applies to EVERY [Scrollable] in the
/// tree, and a `SelectableText` contains one of its own. Handing that
/// inner scrollable [AlwaysScrollableScrollPhysics] made it accept a
/// vertical drag it has nothing to scroll — so it won the gesture arena
/// and the page underneath never moved. A reader whose thumb landed on
/// the sermon text found the page dead; a thumb landing on the title,
/// the chips or the margins scrolled normally, which is why it read as
/// "some sermons scroll and some don't" rather than as a bug.
///
/// A display-only text widget should never own a scrollable, so the
/// fix is here rather than in the behavior: dropping
/// `AlwaysScrollableScrollPhysics` from [AppScrollBehavior] would also
/// work, but it would take the short-list rubber-band with it (measured:
/// 120 px of overscroll becomes 0), and that is the deliberate choice
/// documented above. `test/selectable_text_scroll_test.dart` pins both
/// the behaviour and the fact that every call site passes this.
const ScrollPhysics kSelectableTextPhysics = NeverScrollableScrollPhysics();

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
