import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/stacked_card_nav.dart';

class LocalizedBackButton extends StatelessWidget {
  const LocalizedBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: uiStrings['back']?[settings.locale] ?? 'Back',
      onPressed: () {
        // Prefer the StackedCardScaffold layer pop when available — that
        // keeps the page beneath visible underneath the closing card.
        final stack = StackedCardScaffold.maybeOf(context);
        if (stack != null && stack.hasOverlays) {
          stack.pop();
          return;
        }
        Get.back();
      },
    );
  }
}
