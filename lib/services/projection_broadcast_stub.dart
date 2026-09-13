// Native half of `projection_broadcast.dart`: no follower window exists
// off the web, so every call is a no-op and nothing is supported.

import 'projection_broadcast.dart' show ProjectionFrame;

bool get projectionBroadcastSupported => false;
void projectionBroadcastOpenStage() {}
void projectionBroadcastPost(ProjectionFrame frame) {}
void projectionBroadcastClose() {}
