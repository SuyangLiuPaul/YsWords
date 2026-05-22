// 2026-05-20 (v1.2.67 follow-up): native no-op. On iOS / Android
// the platform channels are wired by the Pigeon-generated
// MethodChannel implementations the Flutter Firebase plugins
// ship — no web-side registration needed.

void registerWebPluginsIfNeeded() {
  // No-op on native.
}
