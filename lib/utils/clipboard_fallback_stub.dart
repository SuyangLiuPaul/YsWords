/// Non-web stub for the legacy clipboard fallback. On iOS / Android /
/// macOS the platform `Clipboard.setData` channel is reliable, so
/// there is nothing sensible to fall back to — report failure and let
/// the caller show its failure feedback.
bool legacyClipboardCopy(String text) => false;
