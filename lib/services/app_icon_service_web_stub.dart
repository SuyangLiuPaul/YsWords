// Non-web stub for [AppIconService]'s favicon swap. The conditional
// import in app_icon_service.dart pulls this on every non-web platform
// (dart:io is available) so the symbol resolves at analyze time but
// is never actually called — the AppIconService.updateForColor path
// gates on `kIsWeb` before reaching this.

void setFaviconForVariant(String? variant) {
  // No-op on native.
}
