// OBSOLETE — 2026-05-24 (v1.3.18). This file used to be the
// web-only TTS implementation backed by `window.speechSynthesis`
// via dart:js_interop. The new tts_service.dart wraps the
// `flutter_tts` package which has web support built-in, plus
// native iOS / macOS / Android implementations.
//
// This file is no longer referenced. Kept as an empty placeholder
// in case any stale tooling still resolves the old conditional
// import path; safe to delete on the next repo cleanup.
library;
