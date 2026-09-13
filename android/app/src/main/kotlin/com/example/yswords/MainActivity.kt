package com.example.yswords

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// 2026-08-24: MUST extend AudioServiceActivity, not FlutterActivity.
// AudioServiceActivity is a FlutterActivity that hands back the engine
// audio_service caches under "audio_service_engine". A plain
// FlutterActivity builds its own engine instead, so audio_service finds
// the cache empty in onAttachedToActivity and creates a SECOND engine —
// which runs main() again in a second isolate. Measured on an emulator
// before this change: two YSWORDS_BOOT_MARKER lines from one pid, and
// `AudioService.init` failing in the UI isolate with "The Activity class
// declared in your AndroidManifest.xml is wrong", i.e. no lock-screen
// controls and no foreground service on Android at all.
class MainActivity : AudioServiceActivity() {
    // 2026-05-24 (v1.2.97): themed launcher icon variants. Each
    // alias is declared in AndroidManifest.xml and points at this
    // same activity. We enable exactly one alias (or the main
    // MainActivity component itself) at a time via
    // PackageManager.setComponentEnabledSetting.
    //
    // Aliases must be referenced by their full ComponentName
    // (PACKAGE/.AliasName) — Android won't accept relative names
    // here even though the manifest uses `.AliasRed`.
    private val pkg = "com.example.yswords"
    private val aliasMap = mapOf(
        // Map alternate-icon name (sent by Dart) → component class
        // path. Null key = "primary icon" = the main MainActivity.
        "AppIcon-Red"    to "$pkg.AliasRed",
        "AppIcon-Orange" to "$pkg.AliasOrange",
        "AppIcon-Green"  to "$pkg.AliasGreen",
        "AppIcon-Purple" to "$pkg.AliasPurple",
        "AppIcon-Pink"   to "$pkg.AliasPink",
        "AppIcon-Dark"   to "$pkg.AliasDark",
    )
    private val mainComponent = "$pkg.MainActivity"

    // 2026-06-16 (v1.3.85): the launcher-icon swap MUST be deferred
    // until the app leaves the foreground.
    //
    // BUG it fixes: changing the theme colour made the Android app
    // "quit" the instant the colour changed. The swap disables the
    // component the running task is rooted on (MainActivity when
    // leaving the default blue, or the active alias when switching
    // between colours). Disabling that component makes Android FINISH
    // the task — `DONT_KILL_APP` only spares the *process*, not the
    // task whose root component you just disabled. So the foreground
    // activity was torn down out from under the user every time.
    //
    // FIX: record the desired icon and apply the actual
    // setComponentEnabledSetting swap in onStop(), i.e. once the
    // activity is no longer visible. A stopped activity instance is
    // kept warm by the system, so disabling its component there is
    // safe — the launcher shows the new icon by the time the user
    // returns, and the app is never killed. This matches how
    // production apps (Telegram et al.) do runtime icon switching.
    //
    // `pendingIconName` holds the alternate-icon key (or null =
    // revert to primary); `hasPendingIcon` distinguishes "queued a
    // revert-to-primary (null)" from "nothing queued".
    private var pendingIconName: String? = null
    private var hasPendingIcon = false

    // 2026-09-09 (review finding 4): the "install unknown apps" request
    // answers Dart only when the reader comes BACK from the settings
    // screen, not when it opens. Before this, `success(true)` was sent
    // the instant `startActivity` returned, so Dart could not tell "the
    // screen opened" from "they granted it" — and the reader returned
    // to a dialog telling them to press 「立即更新」 again, a button that
    // was no longer anywhere on screen. The pending result is held in
    // the companion object below and completed with the switch's state
    // at the moment the reader comes back.
    private val requestUnknownSources = 0x5EEC

    // 2026-09-09 (remediation, finding 1): the parked result MUST NOT
    // live on the Activity instance, and answering it MUST NOT depend
    // on `onActivityResult` arriving.
    //
    // The Flutter engine outlives this Activity. `AudioServiceActivity`
    // hands back the engine cached under "audio_service_engine" (see
    // the class comment above), so when Android destroys MainActivity
    // while the Settings screen is in front — "Don't keep activities",
    // or ordinary memory pressure on the owner's Mi Pad, which is the
    // device this file's header was written about — a NEW MainActivity
    // is created against the SAME engine, the SAME Dart isolate, and
    // the SAME pending `invokeMethod` future. An instance field died
    // with the old instance: the new one's `pendingPermissionResult`
    // was null, `?.success(...)` replied to nobody, and Dart's
    // `requestPermission()` never completed — which left
    // `updateInstallInProgress` latched true and every later "Update
    // now" a silent no-op for the life of the process.
    //
    // Static, so the field's lifetime matches the engine's rather than
    // the Activity's; and answered from `onResume` as well as from
    // `onActivityResult`, because the recreated instance never gets the
    // result callback (it did not start the activity) but is always
    // resumed when the reader comes back.
    companion object {
        private var pendingPermissionResult: MethodChannel.Result? = null
        private var permissionRequestOutstanding = false
    }

    /// Answer a permission request that is still waiting, with the
    /// switch's state right now.
    ///
    /// Reads `canRequestPackageInstalls()` rather than any result code:
    /// the settings screen returns RESULT_CANCELED whether or not the
    /// switch was touched, so the switch itself is the only honest
    /// answer — and it is an answer a recreated Activity can give just
    /// as well as the one that asked.
    private fun answerPendingPermission() {
        if (!permissionRequestOutstanding) return
        permissionRequestOutstanding = false
        val result = pendingPermissionResult
        pendingPermissionResult = null
        val granted =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                packageManager.canRequestPackageInstalls()
            } else {
                true
            }
        try {
            result?.success(granted)
        } catch (e: Exception) {
            // The engine can be gone (the whole app was killed and this
            // is a cold start). Nothing to answer, and a crash here
            // would be a crash on resume.
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/android_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentIconName" -> {
                        // If a swap is queued but not yet applied (we apply on
                        // onStop), report the QUEUED choice so Dart's
                        // "already set → skip" guard stays consistent with what
                        // the user just picked. Otherwise read the live state:
                        // walk every alias; whichever is ENABLED is "current".
                        // If none, return null (= primary icon).
                        if (hasPendingIcon) {
                            result.success(pendingIconName)
                            return@setMethodCallHandler
                        }
                        val pm = applicationContext.packageManager
                        var found: String? = null
                        for ((iconName, klass) in aliasMap) {
                            val comp = ComponentName(pkg, klass)
                            val state = pm.getComponentEnabledSetting(comp)
                            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                                found = iconName
                                break
                            }
                        }
                        result.success(found)
                    }
                    "setIcon" -> {
                        val args = call.arguments as? Map<*, *>
                        val name = args?.get("name") as? String
                        // Do NOT apply now — disabling the rooted component
                        // while foreground tears the task down (see the field
                        // doc above). Queue it; onStop() applies it once the
                        // activity is backgrounded.
                        pendingIconName = name
                        hasPendingIcon = true
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // 2026-09-09: hand a downloaded APK to the system installer,
        // so "update" is a button in the app instead of a trip through
        // the browser and the Downloads folder.
        //
        // Three methods and no fourth, because there is no fourth
        // thing this side can honestly do. It cannot install silently
        // (only a device owner can), it cannot report progress (the
        // download happens in Dart), and it cannot tell whether the
        // reader went through with it (the installer is a separate
        // task and returns nothing to us — the app finds out the way
        // everyone else does, by being restarted as the new version).
        // 2026-09-13: "save this song / score as a file". On Android the
        // place a reader expects a download to land is the public
        // Downloads folder, which since API 29 is reachable without any
        // permission through MediaStore — but only from native code. Dart
        // writes the bytes to a temp file and hands the path over; this
        // side inserts a row in the Downloads collection and streams the
        // file into it. Below API 29 the collection does not exist and
        // the answer is null, so Dart falls back to the app's own folder
        // and says so.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/downloads")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        if (path == null || name == null) {
                            result.error("args", "path and name are required", null)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            val values = android.content.ContentValues().apply {
                                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
                                put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mime)
                                put(
                                    android.provider.MediaStore.MediaColumns.RELATIVE_PATH,
                                    android.os.Environment.DIRECTORY_DOWNLOADS
                                )
                            }
                            val resolver = contentResolver
                            val uri = resolver.insert(
                                android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                            )
                            if (uri == null) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            resolver.openOutputStream(uri).use { out ->
                                File(path).inputStream().use { it.copyTo(out!!) }
                            }
                            result.success("Download/$name")
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/apk_installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Below API 26 the permission is granted at install
                    // time and there is no per-app switch to check.
                    "canInstall" -> {
                        val allowed =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                packageManager.canRequestPackageInstalls()
                            } else {
                                true
                            }
                        result.success(allowed)
                    }
                    // Opens the OS screen for THIS app specifically.
                    // Deliberately not a general Settings deep-link:
                    // the reader is one tap from the switch that
                    // matters, and lands back here by pressing Back.
                    //
                    // The reply is deferred to onActivityResult and says
                    // whether the switch is on NOW — see
                    // `pendingPermissionResult`. A second request while
                    // one is already open is refused rather than
                    // replacing it, so the first caller still gets its
                    // answer.
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (permissionRequestOutstanding) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            try {
                                pendingPermissionResult = result
                                permissionRequestOutstanding = true
                                startActivityForResult(
                                    Intent(
                                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                        Uri.parse("package:$packageName")
                                    ),
                                    requestUnknownSources
                                )
                            } catch (e: Exception) {
                                pendingPermissionResult = null
                                permissionRequestOutstanding = false
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    // Where Dart should write the download.
                    //
                    // Asked of this side rather than resolved with
                    // path_provider, and that is not dependency
                    // squeamishness: this directory has to be the one
                    // `res/xml/update_file_paths.xml` declares, or
                    // `FileProvider.getUriForFile` throws
                    // IllegalArgumentException at the last step of an
                    // update the reader has already waited for. One
                    // side owns the path; the other asks.
                    "updateDir" -> {
                        val dir = File(cacheDir, "updates")
                        dir.mkdirs()
                        result.success(dir.absolutePath)
                    }
                    "install" -> {
                        val path = (call.arguments as? Map<*, *>)
                            ?.get("path") as? String
                        if (path == null) {
                            result.error("no_path", "install needs a path", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("missing", "no file at $path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            // A `file://` URI would throw
                            // FileUriExposedException on API 24+; the
                            // provider is declared in the manifest
                            // against `${applicationId}.updates` so the
                            // `.cn` flavour does not collide with the
                            // international build on the same device.
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.updates",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(
                                    uri,
                                    "application/vnd.android.package-archive"
                                )
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    // 2026-09-09 (remediation): which app is asking.
                    //
                    // `release-android.yml` only ever attaches the
                    // `intl` APK, whose applicationId is
                    // `com.example.yswords`. The `cn` flavour runs as
                    // `com.example.yswords.cn`, so handing it that same
                    // APK is not an update at all — Android would treat
                    // a different applicationId as a different app and
                    // install a SECOND copy beside the one the reader
                    // pressed "update" in. Dart compares this against
                    // `AppUpdateInstaller.kReleasePackage` and hides the
                    // button rather than offering the wrong app.
                    "packageName" -> result.success(packageName)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestUnknownSources) return
        // The settings screen's own result code says nothing useful
        // (it is RESULT_CANCELED whether or not the switch was
        // touched), so `answerPendingPermission` re-reads the switch —
        // which is the only fact Dart needs to decide whether to carry
        // on installing. This is the happy path: the instance that
        // asked is still alive and gets the callback.
        answerPendingPermission()
    }

    override fun onResume() {
        super.onResume()
        // 2026-09-09 (remediation, finding 1): the path the happy one
        // above cannot cover. If Android destroyed the Activity while
        // the Settings screen was in front, THIS instance never started
        // that activity and will never receive its result — but it is
        // the instance the reader comes back to, and the engine holding
        // the waiting Dart future is the same one. A no-op whenever
        // nothing is outstanding, which is every other resume in the
        // app's life.
        answerPendingPermission()
    }

    override fun onStop() {
        super.onStop()
        // Apply any queued launcher-icon swap now that the activity is no
        // longer visible — safe to disable the (now backgrounded) rooted
        // component here without killing the app.
        if (hasPendingIcon) {
            applyIcon(pendingIconName)
            hasPendingIcon = false
        }
    }

    /// Enable the target alias (or the primary MainActivity when
    /// [name] is null) and disable every other launcher component so
    /// exactly one icon shows. Best-effort: PackageManager can throw
    /// on locked-down OEM ROMs; there is nothing actionable to do but
    /// swallow it so a backgrounding never crashes.
    private fun applyIcon(name: String?) {
        val pm = applicationContext.packageManager
        val targetAlias: String? = name?.let { aliasMap[it] }
        try {
            if (targetAlias != null) {
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, targetAlias),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                // Disable the primary (so two icons don't show).
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, mainComponent),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            } else {
                // Reverting to primary: enable MainActivity; the loop
                // below disables every alias.
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, mainComponent),
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            // Disable every OTHER alias (and the primary if we just
            // enabled an alias above).
            for ((_, klass) in aliasMap) {
                if (klass == targetAlias) continue
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, klass),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            // Best-effort; nothing else we can do at backgrounding time.
        }
    }
}
