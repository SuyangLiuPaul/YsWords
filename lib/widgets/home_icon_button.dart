import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:provider/provider.dart';

/// AppBar leading button that pops the navigator stack down to the
/// root (Dashboard) so users can return Home from any nested page
/// in one tap. Uses `popUntil((r) => r.isFirst)` so it correctly
/// collapses Settings → Highlights → Reader → Dashboard or any
/// other nesting depth without us having to track the stack
/// manually.
///
/// Designed to live in the AppBar's `leading` slot (top-left) —
/// standard mobile/web placement for primary navigation. On
/// pages that ARE the root, `Navigator.canPop` is false; the
/// button self-hides via SizedBox.shrink so the slot collapses
/// and AppBar centers its title correctly.
class HomeIconButton extends StatelessWidget {
  const HomeIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final canPop = Navigator.of(context).canPop();
    if (!canPop) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.home_rounded),
      tooltip: uiStrings['home']?[settings.locale] ?? 'Home',
      onPressed: () =>
          Navigator.of(context).popUntil((r) => r.isFirst),
    );
  }
}
