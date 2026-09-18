/// Native platforms (iOS / macOS / Android) — the app IS already an
/// installed native binary; no install affordance needed.
library;

import 'package:yahwehs_words/services/install_prompt_service.dart';

InstallFlowKind detect() => InstallFlowKind.notApplicable;

Future<String> show() async => 'unavailable';
