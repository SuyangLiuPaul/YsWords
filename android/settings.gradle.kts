pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 2026-08-11 (v1.4.40): raised from 8.7.0. Adding pdfrx for the
    // in-app sheet-music viewer brings url_launcher_android with it,
    // whose androidx.browser:1.9.0 and androidx.core:1.17.0 both refuse
    // to build under an AGP older than 8.9.1 —
    // :app:checkIntlReleaseAarMetadata listed all three as errors.
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    // 2026-05-21 (v1.2.68): Firebase on Android reads
    // android/app/google-services.json via this gradle plugin.
    // Declared at settings level + `apply true` in app/build.gradle
    // so Firebase APIs (auth, Firestore, RTDB) initialise from the
    // downloaded config instead of crashing on FirebaseApp.initializeApp.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
