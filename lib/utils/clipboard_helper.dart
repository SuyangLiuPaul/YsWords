// lib/utils/clipboard_helper.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

abstract class ClipboardHelper {
  static Future<void> copyText(String text) async {
    if (kIsWeb) {
      try {
        await html.window.navigator.clipboard?.writeText(text);
      } catch (_) {
        // Fallback for browsers without Clipboard API
        final textArea = html.TextAreaElement();
        textArea.value = text;
        html.document.body?.append(textArea);
        textArea.select();
        html.document.execCommand('copy');
        textArea.remove();
      }
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
