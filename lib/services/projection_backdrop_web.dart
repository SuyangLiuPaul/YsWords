/// The web half of `projection_backdrop.dart`: there is no backdrop.
///
/// A browser gives `image_picker` a blob URL, which does not survive a
/// reload and cannot be copied anywhere durable, so the honest answer
/// is that this build does not keep one. The Settings card reads
/// [projectionBackdropSupported] and shows
/// `projectionBackdropUnavailable` instead of a control that would
/// forget.
///
/// Every function still exists, so nothing has to ask which platform it
/// is on.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart' show ImageProvider;

const String kProjectionBackdropFileName = 'projection-backdrop.img';

bool get projectionBackdropSupported => false;

Future<String?> storeProjectionBackdrop(Uint8List bytes) async => null;

Future<void> clearProjectionBackdrop() async {}

ImageProvider? projectionBackdropImage(String path) => null;
