import 'package:flutter/material.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:provider/provider.dart';

/// AppBar action button that pops the navigator stack down to the
/// root (Dashboard) so users can return Home from any nested page
/// in one tap. Uses `popUntil((r) => r.isFirst)` so it correctly
/// collapses Settings → Highlights → Reader → Dashboard or any
/// other nesting depth without us having to track the stack
/// manually.
///
/// No-op when already at the root (Navigator.canPop returns false),
/// so dropping it into Dashboard's own AppBar is harmless.
class HomeIconButton extends StatelessWidget {
  const HomeIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final canPop = Navigator.of(context).canPop();
    if (!canPop) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: uiStrings['home']?[settings.locale] ?? 'Home',
      onPressed: () =>
          Navigator.of(context).popUntil((r) => r.isFirst),
    );
  }
}
