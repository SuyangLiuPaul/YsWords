// Stub: no native share sheet on non-web targets.
bool shareIsAvailable() => false;
Future<bool> shareText({
  required String text,
  String? title,
  String? url,
}) async =>
    false;
