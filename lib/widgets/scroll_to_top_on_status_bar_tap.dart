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
class ScrollToTopOnStatusBarTap extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const ScrollToTopOnStatusBarTap({
    super.key,
    required this.controller,
    required this.child,
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
