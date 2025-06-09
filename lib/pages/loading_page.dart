import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/verse.dart';
import 'home_page.dart';

class LoadingPage extends StatefulWidget {
  final List<Verse> verses;
  const LoadingPage({super.key, required this.verses});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    // final today = DateTime.now();
    final verse =
        widget.verses.isNotEmpty ? (widget.verses..shuffle()).first : null;

    final notePattern = RegExp(r'<note:[^>]*>');
    final bracePattern = RegExp(r'\{[^}]*\}');
    final squarePattern = RegExp(r'\[([^\]]+)\]');
    // Combined to split text and bracket tokens
    final combinedPattern = RegExp(r'(\[[^\]]+\])');
    final original = verse?.text.replaceAll('\n', '') ?? '';
    // Remove only notes and braces, keep square brackets for rendering
    final raw = original
        .replaceAll(notePattern, '')
        .replaceAll(bracePattern, '')
        .trim();
    // Split so that each [word] is its own part
    final parts = raw
        .splitMapJoin(
          combinedPattern,
          onMatch: (m) => '||${m[0]}||',
          onNonMatch: (n) => n,
        )
        .split('||');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: verse == null
            ? const Text('No verses available')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/loading.png',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Text(
                        'YsWords',
                        style: TextStyle(
                          fontSize: settings.fontSize * 1.2,
                          fontFamily: settings.fontFamily,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '雅伟之言',
                        style: TextStyle(
                          fontSize: settings.fontSize * 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: parts.map<InlineSpan>((part) {
                          final match = squarePattern.firstMatch(part);
                          if (match != null) {
                            return TextSpan(
                              text: match.group(1),
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                                height: 1.5,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                                decorationColor:
                                    Theme.of(context).colorScheme.primary,
                                decorationThickness: 2.0,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            );
                          } else {
                            return TextSpan(
                              text: part,
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                                height: 1.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${verse.book} ${verse.chapter}:${verse.verse}',
                    style: TextStyle(
                      fontSize: settings.fontSize * 0.9,
                      color: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.color
                          ?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
