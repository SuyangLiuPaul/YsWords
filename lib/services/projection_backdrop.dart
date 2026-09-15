/// The operator's own picture for the wall — see
/// `projection_backdrop_io.dart` for what this is and why the picked
/// file is copied rather than pointed at.
///
/// Split the way `media_embed.dart` and `verse_card_export.dart` are,
/// because the native half needs `dart:io` and the web half must not
/// see it.
library;

export 'projection_backdrop_io.dart'
    if (dart.library.js_interop) 'projection_backdrop_web.dart';
