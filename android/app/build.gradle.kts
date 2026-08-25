import java.util.Properties

// 2026-08-25: optional release signing.
//
// Until now the release build was signed with the DEBUG key — the
// `signingConfig` below still says so when this file is absent, and the
// template's "TODO: Add your own signing config" had never been done. A
// release APK carrying a debug certificate is not merely untidy: Play
// Protect and the OEM scanners on Xiaomi and Huawei treat it as a real
// signal, which is the difference between a friend seeing the ordinary
// "install from unknown sources?" prompt and seeing "此应用可能有害".
//
// The key itself is a credential and belongs to the user, not to this
// repo. Create it once:
//
//   keytool -genkey -v -keystore ~/yswords-release.jks -storetype JKS \
//     -keyalg RSA -keysize 2048 -validity 10000 -alias yswords
//
// then write android/key.properties (already gitignored, along with
// *.jks and *.keystore):
//
//   storeFile=/Users/<you>/yswords-release.jks
//   storePassword=<what you chose>
//   keyAlias=yswords
//   keyPassword=<what you chose>
//
// Absent that file the build falls back to the debug key exactly as
// before, so CI and `flutter run --release` keep working untouched.
//
// KEEP THE .jks AND ITS PASSWORD. Android identifies an app by its
// signature: lose the key and no future build can ever update an
// installed copy — every user has to uninstall and lose their local
// data first.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // 2026-05-21 (v1.2.68): apply Google services plugin so the
    // build picks up android/app/google-services.json and wires
    // Firebase auto-init at app startup. Plugin declared in
    // android/settings.gradle.kts.
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.yswords"
    compileSdk = flutter.compileSdkVersion
    // 2026-08-11 (v1.4.40): raised from 27.0.12077973. Adding pdfrx for
    // the in-app sheet-music viewer pulls in `jni` (via pdfium_dart),
    // and both it and integration_test require 28.2.13676358 — the
    // Android build failed at :app:checkIntlReleaseAarMetadata until
    // this matched. NDK releases are backward compatible, so taking the
    // highest required version is the documented fix rather than a
    // workaround.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // 2026-05-21 (v1.2.69): flutter_local_notifications uses
        // java.time APIs that need core library desugaring on older
        // Android. Enabled here + dependency added below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.yswords"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 2026-05-24 (v1.3.38): default app_name. Each productFlavor
        // below overrides this with its own resValue("app_name", ...)
        // so the home-screen label differs between the international
        // and China-mode coexist builds.
        // app_name now lives in src/{main,cn}/res — see the WHY note
        // in src/main/res/values/strings.xml (lint ExtraTranslation).
    }

    // 2026-05-24 (v1.3.38): product flavors so the international
    // (default) build and the China-mode build can coexist on the
    // same Android device. The `cn` flavor uses
    //   applicationIdSuffix=".cn"  → installs as `com.example.yswords.cn`
    //   resValue app_name="YsWords CN" → distinct home-screen label
    // and is paired at build time with `--dart-define=CHINA_MODE=true`
    // which gates the runtime behavior (Firebase init skipped,
    // Google Fonts options hidden, etc.). Build commands:
    //   intl: flutter build apk --release --flavor intl
    //   cn:   flutter build apk --release --flavor cn --dart-define=CHINA_MODE=true
    flavorDimensions += "region"
    productFlavors {
        create("intl") {
            dimension = "region"
            // applicationId + app_name remain the defaultConfig
            // values; this flavor is just a symmetric label so the
            // build commands look parallel.
        }
        create("cn") {
            dimension = "region"
            applicationIdSuffix = ".cn"
        }
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real key when android/key.properties exists, debug key when
            // it does not — see the note at the top of this file. The
            // fallback is deliberate: CI has no keystore and must still be
            // able to build, and a build that fails for a missing secret
            // teaches people to ignore red.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 2026-05-21 (v1.2.69): desugar_jdk_libs ships back-ports of java.time
// and other Java 8+ APIs that flutter_local_notifications relies on.
// Required by isCoreLibraryDesugaringEnabled above.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// 2026-05-24 (v1.3.38): skip the Google Services plugin for the cn
// flavor. The plugin validates the applicationId against the
// `client_info.package_name` array in google-services.json — our
// JSON only registers com.example.yswords (the international flavor),
// so build fails with "No matching client found for package name
// com.example.yswords.cn" on every cn-flavor build.
//
// The China build runs `kChinaMode == true` and `CloudAuthService`
// short-circuits before any Firebase API is touched (see
// build_flags.dart for the contract), so we don't actually need
// the plugin's bookkeeping at all for cn. Disabling the plugin
// tasks lets the build proceed without re-registering the .cn
// package in Firebase Console.
afterEvaluate {
    listOf("processCnDebugGoogleServices",
           "processCnProfileGoogleServices",
           "processCnReleaseGoogleServices").forEach { taskName ->
        tasks.findByName(taskName)?.enabled = false
    }
}
