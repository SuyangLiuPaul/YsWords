import 'package:flutter/material.dart';

/// Show a transient pill-shaped toast in the **root** Overlay so it
/// renders ABOVE any modal bottom sheet / dialog / route on the
/// stack. Default `ScaffoldMessenger.showSnackBar` renders at the
/// Scaffold level which a modal sheet can cover — that's why this
/// exists.
///
/// Auto-dismisses after [duration] (default 2 s).
void showFloatingToast(
  BuildContext context, {
  required String message,
  required IconData icon,
  required Color background,
  Duration duration = const Duration(milliseconds: 2000),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final OverlayEntry entry;
  entry = OverlayEntry(builder: (ctx) {
    final media = MediaQuery.of(ctx);
    return Positioned(
      left: 0,
      right: 0,
      top: media.padding.top + 24,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });
  overlay.insert(entry);
  Future.delayed(duration, () => entry.remove());
}
