// Firebase configuration. Replace the placeholder strings below with
// the values from YOUR Firebase project to enable cloud sync. Until
// you do, the app keeps using local-only profiles (no crash, no
// network calls — `CloudAuthService.isConfigured` returns false).
//
// One-time setup (~15 minutes):
// ──────────────────────────────────────────────────────────────────
// 1. Go to https://console.firebase.google.com and click
//    "Add project". Name it whatever you like (e.g. "yswords").
//    Disable Google Analytics for the simplest path.
//
// 2. Click the </> Web icon to register a web app. Copy the
//    `firebaseConfig` object that appears — those are the values
//    you'll paste below.
//
// 3. In the Firebase console sidebar:
//    • Build → Authentication → Get started
//      Sign-in method tab → Email/Password → Enable → Save
//    • Build → Firestore Database → Create database
//      Start in "production mode" (rules below)
//      Pick a location near your users (e.g. nam5 for US)
//
// 4. Authentication → Settings → Authorized domains tab → Add domain
//      Add `yswords.netlify.app`
//      `localhost` is already authorised by default for dev.
//
// 5. Firestore Database → Rules tab → paste these rules → Publish:
//
//      rules_version = '2';
//      service cloud.firestore {
//        match /databases/{database}/documents {
//          match /users/{uid}/{doc=**} {
//            allow read, write: if request.auth != null
//                                  && request.auth.uid == uid;
//          }
//        }
//      }
//
//    These rules let each authenticated user read+write only their
//    own documents (`users/{their-uid}/...`). Nobody else can see
//    or modify their data.
//
// 6. Replace the placeholder values below with the ones from step 2.
//    Save the file, run `flutter build web --release`, and deploy.
//
// 7. Done — Sign in with Email button on the welcome page lights up.

import 'package:firebase_core/firebase_core.dart';

/// Whether [DefaultFirebaseOptions.web] holds real values. The
/// CloudAuthService consults this before attempting Firebase init —
/// keeping the app crash-free until the user finishes setup.
bool get firebaseConfigured =>
    DefaultFirebaseOptions.web.apiKey != _placeholder &&
    DefaultFirebaseOptions.web.projectId != _placeholder;

const _placeholder = 'FILL_ME_IN';

class DefaultFirebaseOptions {
  /// Web-target options. We don't ship native iOS/Android right now;
  /// if you ever do, run `flutterfire configure` to regenerate this
  /// file with android/ios/macos/windows entries too.
  ///
  /// These values are public by design — they identify the project,
  /// not authenticate it. Privacy is enforced by Firestore security
  /// rules (see firebase_options.dart header / HANDOFF.md), which
  /// require `request.auth.uid == uid` for any read or write.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBKa1M1de_9ALJe_AD7vcDDVTBgtSW3_P8',
    appId: '1:461522287670:web:764f0dcb592564b15dec97',
    messagingSenderId: '461522287670',
    projectId: 'ysword',
    authDomain: 'ysword.firebaseapp.com',
    storageBucket: 'ysword.firebasestorage.app',
    measurementId: 'G-1TB1F4XNB8',
    // 2026-05-06: Realtime Database URL for cross-device sync.
    // The standard default-region URL pattern is
    //   https://<project-id>-default-rtdb.firebaseio.com
    // but US-region projects may instead get
    //   https://<project-id>-default-rtdb.firebasedatabase.app
    // If sign-in works but sync is silently failing, double-check
    // this value matches what Firebase Console → Realtime Database
    // shows in the data-tab URL bar.
    databaseURL: 'https://ysword-default-rtdb.firebaseio.com',
  );
}
