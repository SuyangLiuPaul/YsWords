package com.example.yswords

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
