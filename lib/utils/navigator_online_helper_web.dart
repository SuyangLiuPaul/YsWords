// 2026-05-20 (v1.2.67): web impl — reads the browser's
// `navigator.onLine` flag via dart:js_interop. False when the
// browser believes the device has no network connectivity.

import 'dart:js_interop';

@JS('navigator.onLine')
external bool get _navigatorOnLine;

bool get isOnline => _navigatorOnLine;
