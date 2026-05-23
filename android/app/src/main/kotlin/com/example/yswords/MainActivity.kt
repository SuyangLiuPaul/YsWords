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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yswords/android_icon")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "currentIconName" -> {
                        // Walk every alias; whichever is ENABLED is "current".
                        // If none, return null (= primary icon).
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
                        val pm = applicationContext.packageManager
                        // Determine target alias (null = revert to primary).
                        val targetAlias: String? = name?.let { aliasMap[it] }
                        try {
                            // Step 1: enable the new component.
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
                                // Reverting to primary: enable MainActivity,
                                // we'll disable all aliases below.
                                pm.setComponentEnabledSetting(
                                    ComponentName(pkg, mainComponent),
                                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                                    PackageManager.DONT_KILL_APP
                                )
                            }
                            // Step 2: disable every OTHER alias (and primary if
                            // we just enabled an alias).
                            for ((_, klass) in aliasMap) {
                                if (klass == targetAlias) continue
                                pm.setComponentEnabledSetting(
                                    ComponentName(pkg, klass),
                                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    PackageManager.DONT_KILL_APP
                                )
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
