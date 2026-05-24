/// Centralized haptic feedback wrapper for YsWords interactions.
library;
///
/// 2026-05-24 (v1.3.17): added in response to "ios macos and android
/// more improvement" — verse tap, chapter swipe, and other discrete
/// interactions had no tactile feedback. Apple's HIG and Material 3
/// guidelines both call for haptics on small confirmatory actions.
///
/// Flutter's `HapticFeedback` class is already cross-platform-aware:
///   - iOS: invokes the real Taptic Engine (iPhone 7+) via
///     `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator`.
///     The iPhone 16 Pro Max has a 4th-gen engine — these feel great.
///   - Android: uses `View.performHapticFeedback` with the right
///     `HapticFeedbackConstants` for each call. Works on every
///     Android since Honeycomb but quality varies by device's
///     vibration motor.
///   - macOS: no-op on Intel Macs (no haptic hardware); Apple Silicon
///     MacBooks with a Force Touch trackpad get a soft click via
///     `NSHapticFeedbackManager`.
///   - Web / Linux / Windows: no-op (no underlying API).
///
/// We wrap each call in this file rather than scattering
/// `HapticFeedback.x()` across the codebase so that:
///   1. A future "reduce haptics" user setting can short-circuit
///      every site by gating in one place.
///   2. We can swap in different intensities centrally without
///      hunting call sites.
///   3. Tests can mock this module without touching the platform
///      channel directly.

import 'package:flutter/services.dart';

/// Light "click" used for discrete UI selections — verse tap,
/// chip toggle, checkbox check. Maps to `selectionClick()` which
/// is the lightest tactile response available.
Future<void> hapticSelect() async {
  try {
    await HapticFeedback.selectionClick();
  } catch (_) {
    // Platform channel can throw on unsupported platforms during
    // first-frame race. Silent no-op is the right behavior.
  }
}

/// Light impact for confirmations — chapter swipe complete,
/// search submit, settings save. Stronger than a selection click
/// but still subtle.
Future<void> hapticLight() async {
  try {
    await HapticFeedback.lightImpact();
  } catch (_) {/* no-op */}
}

/// Medium impact for important state changes — bookmark added,
/// highlight applied, note saved. Reserved for moments where the
/// user crossed a meaningful threshold.
Future<void> hapticMedium() async {
  try {
    await HapticFeedback.mediumImpact();
  } catch (_) {/* no-op */}
}

/// Heavy impact reserved for errors / warnings — verse already
/// at edge of canon, network failure on retry. Used sparingly.
Future<void> hapticHeavy() async {
  try {
    await HapticFeedback.heavyImpact();
  } catch (_) {/* no-op */}
}
