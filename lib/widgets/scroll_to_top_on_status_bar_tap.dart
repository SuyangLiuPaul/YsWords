import 'package:flutter/material.dart';

/// Restores the iOS "tap the status bar to jump to the top" gesture for
/// a list that owns its own [ScrollController].
///
/// 2026-08-11, reported from an iPhone: "I thought click top will go to
/// top automatically in iPhone, it is not, as well in all pages?"
///
/// Flutter *does* ship this. The engine sends `handleScrollToTop`,
/// `WidgetsBinding` fans it out to every [WidgetsBindingObserver], and
/// material's `Scaffold` implements it by animating
/// `PrimaryScrollController` to zero. The catch is in what attaches to
/// that controller: a vertical scroll view opts in automatically **only
/// when it has no `controller:` of its own**. Twenty-seven scroll views
/// in this app pass one — for `scroll_to_index`, for positioned lists,
/// for "scroll to the verse you were reading" — so on every one of those
/// pages the gesture silently did nothing.
///
/// Removing those controllers is not an option; they are load-bearing.
/// So this wrapper listens for the same notification and drives the
/// controller the page already has.
///
/// Only the visible route responds. Every page in the navigator stack
/// registers its own observer, and without the [ModalRoute.isCurrent]
/// check a status-bar tap would also scroll three pages the user cannot
/// see — which they would discover later as "it lost my place".
///
/// A route is not the only thing that hides a list. Inside a
/// [TabBarView] every mounted tab shares ONE route, so [ModalRoute]
/// says "current" for all of them at once — see [tabIndex].
class ScrollToTopOnStatusBarTap extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  /// The index of the tab this wrapper lives in, when it lives inside a
  /// [TabBarView].
  ///
  /// Needed because the [ModalRoute.isCurrent] check above cannot see
  /// tabs. `TabBarView` keeps the adjacent tab mounted, and a tab that
  /// mixes in `AutomaticKeepAliveClientMixin` (all three of
  /// `stats_page`'s do) stays mounted for the life of the page — so its
  /// observer is registered and its route IS current while the reader is
  /// looking at a different tab entirely. Wiring such a tab without this
  /// guard makes a status-bar tap on the visible tab silently scroll the
  /// hidden one to the top, which is the same "it lost my place" failure
  /// the route check exists to prevent, just across tabs instead of
  /// across routes.
  ///
  /// Compared against `DefaultTabController.of(context).index`. When it
  /// is non-null and there is no controller above this widget the tap is
  /// REFUSED rather than honoured: a caller that passes an index is
  /// declaring it is inside tabs, so a missing controller is a wiring
  /// mistake, and the safe answer to "I cannot tell whether this list is
  /// visible" is to leave the reader's place alone.
  final int? tabIndex;

  const ScrollToTopOnStatusBarTap({
    super.key,
    required this.controller,
    required this.child,
    this.tabIndex,
  });

  @override
  State<ScrollToTopOnStatusBarTap> createState() =>
      _ScrollToTopOnStatusBarTapState();
}

class _ScrollToTopOnStatusBarTapState extends State<ScrollToTopOnStatusBarTap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void handleStatusBarTap() {
    super.handleStatusBarTap();
    if (!mounted) return;
    // Backgrounded routes keep their observers registered.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    // …and so do backgrounded TABS, which the route check cannot see.
    final tabIndex = widget.tabIndex;
    if (tabIndex != null) {
      final tabs = DefaultTabController.maybeOf(context);
      if (tabs == null) return;
      if (tabs.index != tabIndex) return;
    }

    final c = widget.controller;
    // `hasClients` is not enough on its own: a controller attached to
    // several positions (a page that briefly has two lists alive during
    // a transition) throws on `offset`/`animateTo`.
    if (!c.hasClients || c.positions.length != 1) return;
    if (c.offset <= 0) return;

    c.animateTo(
      0,
      // Matches material Scaffold's own values, so a page using this and
      // a page relying on the built-in behave identically.
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCirc,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
