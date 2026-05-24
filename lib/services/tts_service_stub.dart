// OBSOLETE — 2026-05-24 (v1.3.18). This file used to be the
// non-web fallback that returned `false` from `ttsIsAvailable()`
// so native iOS / macOS / Android got a silent no-op for TTS.
// It was selected via a conditional import in tts_service.dart.
//
// v1.3.18 replaced the web-only TTS plumbing with `flutter_tts`,
// which has native implementations on every platform we ship. The
// conditional import is gone; this file is no longer referenced
// from anywhere in `lib/`. Kept as an empty placeholder so an old
// git checkout's analyzer-level reference doesn't break. Safe to
// delete on the next round of repo cleanup.
library;
