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
