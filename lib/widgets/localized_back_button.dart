import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';

class LocalizedBackButton extends StatelessWidget {
  const LocalizedBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: uiStrings['back']?[settings.locale] ?? 'Back',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}