import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yahwehs_words/constants/ui_strings.dart';
import 'package:yahwehs_words/models/app_settings.dart';

class LocalizedBackButton extends StatelessWidget {
  const LocalizedBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: uiStrings['back']?[settings.locale] ?? 'Back',
      onPressed: () => Get.back(),
    );
  }
}
