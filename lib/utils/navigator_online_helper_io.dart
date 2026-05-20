// 2026-05-20 (v1.2.67): native stub — always returns true on
// iOS / Android / desktop. The shared callers in
// cloud_sync_service.dart treat `false` as "skip the upload,
// device is offline" — assuming online on native means network
// ops attempt and fail with a clear error rather than silently
// skipping. That's the right default; if real online/offline
// detection is needed on native later, add `connectivity_plus`
// and wire it into this stub.

bool get isOnline => true;
