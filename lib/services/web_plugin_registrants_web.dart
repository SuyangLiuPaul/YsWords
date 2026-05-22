// 2026-05-20 (v1.2.67 follow-up): web impl — the v1.2.49 "self-
// register Firebase web plugins" logic, extracted out of
// cloud_auth_service.dart so the native build doesn't pull in
// `dart:ui_web` transitively.
//
// Re-registering each plugin is idempotent — if the Flutter-
// generated `web_plugin_registrant.dart` already ran, calling
// `registerWith(webPluginRegistrar)` again is a no-op. This is
// the "belt-and-braces" defence against the cached-registrant
// bug that caused round-49's silent Google-sign-in failure.

// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_web/cloud_firestore_web.dart'
    show FirebaseFirestoreWeb;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show FirebaseAuthPlatform;
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_web/firebase_auth_web.dart'
    show FirebaseAuthWeb;
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart'
    show FirebasePlatform;
// ignore: depend_on_referenced_packages
import 'package:firebase_core_web/firebase_core_web.dart' show FirebaseCoreWeb;
// ignore: depend_on_referenced_packages
import 'package:firebase_database_web/firebase_database_web.dart'
    show FirebaseDatabaseWeb;
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show webPluginRegistrar;

void registerWebPluginsIfNeeded() {
  try {
    if (FirebasePlatform.instance is! FirebaseCoreWeb) {
      FirebaseCoreWeb.registerWith(webPluginRegistrar);
    } else {
      // Auto-registrant already ran; clear the lazy delegate
      // cache so Firebase picks up the live one.
      // ignore: invalid_use_of_visible_for_testing_member
      Firebase.delegatePackingProperty = FirebasePlatform.instance;
    }
    if (FirebaseAuthPlatform.instance.runtimeType.toString() !=
        'FirebaseAuthWeb') {
      FirebaseAuthWeb.registerWith(webPluginRegistrar);
    }
    FirebaseFirestoreWeb.registerWith(webPluginRegistrar);
    FirebaseDatabaseWeb.registerWith(webPluginRegistrar);
  } catch (e) {
    debugPrint('registerWebPluginsIfNeeded: $e');
  }
}
