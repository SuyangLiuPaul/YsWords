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
    ndkVersion = "27.0.12077973"

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
        resValue("string", "app_name", "YsWords")
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
            resValue("string", "app_name", "YsWords CN")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
