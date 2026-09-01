package com.georgeenglezos.rarm

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Two tiny method channels:
//  - storage: "All files access" plumbing for ROM scanning (raw filesystem paths
//    on Android 11+ need MANAGE_EXTERNAL_STORAGE).
//  - emulators: list installed apps and launch a ROM in one, since Android has no
//    exe files; emulators are apps launched via intents, not Process.start.
class MainActivity : FlutterActivity() {
    private val storageChannel = "rarm/storage"
    private val emulatorChannel = "rarm/emulators"

    // A ROM launch parked by tapping a home-screen shortcut (the shortcut
    // trampolines back into this app so the file URI is re-granted and the
    // per-emulator intent is rebuilt in Dart). Dart drains it via
    // takePendingShortcut on startup/resume. null when nothing is pending.
    private var pendingShortcut: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stashShortcut(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stashShortcut(intent)
    }

    // Parks a shortcut-trampoline intent's ROM args for Dart to drain. Ignores
    // the normal launcher/MAIN intent (no shortcut_romPath extra).
    private fun stashShortcut(intent: Intent?) {
        val romPath = intent?.getStringExtra("shortcut_romPath") ?: return
        pendingShortcut = mapOf(
            "romPath" to romPath,
            "package" to intent.getStringExtra("shortcut_package"),
            "kindId" to intent.getStringExtra("shortcut_kindId"),
            "consoleId" to intent.getIntExtra("shortcut_consoleId", 0),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "openAllFilesAccessSettings" -> {
                        openSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, emulatorChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installedApps" -> result.success(installedApps())
                    "launchRom" -> result.success(launchRom(call))
                    "createShortcut" -> result.success(createShortcut(call))
                    "takePendingShortcut" -> {
                        result.success(pendingShortcut)
                        pendingShortcut = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // All launchable apps as [{package, label}], deduped by package (an app can
    // expose several launchers). Which of them are emulators, and the ordering
    // that follows from it, is decided in Dart against EmulatorCatalog: a new
    // emulator package should never need a native change.
    private fun installedApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val seen = HashSet<String>()
        return pm.queryIntentActivities(intent, 0).mapNotNull { ri ->
            val pkg = ri.activityInfo.packageName
            if (pkg == packageName || !seen.add(pkg)) return@mapNotNull null
            mapOf(
                "package" to pkg,
                "label" to ri.loadLabel(pm).toString(),
            )
        }
    }

    // Builds and fires a launch intent from a per-emulator spec assembled in Dart
    // (see AndroidEmulators._spec), mirroring Daijishou's templated intents.
    // Template tokens in `data` and string `extras` are substituted here:
    //   {file.path} -> raw ROM path (apps with storage access, e.g. RetroArch),
    //   {file.uri}  -> FileProvider content URI (raw file:// is blocked since
    //                  Android 7; used by PPSSPP/DuckStation).
    // Returns null on success, or "ExceptionClass: message" so the reason surfaces
    // in the UI instead of being swallowed.
    private fun launchRom(call: io.flutter.plugin.common.MethodCall): String? {
        val romPath = call.argument<String>("romPath")
            ?: return "bad_args: romPath required"
        val componentPkg = call.argument<String>("componentPkg")
        val componentClass = call.argument<String>("componentClass")
        val setPackage = call.argument<String>("setPackage")
        val action = call.argument<String>("action")
        val category = call.argument<String>("category")
        val data = call.argument<String>("data")
        val mimeType = call.argument<String>("mimeType")
        val extras = call.argument<Map<String, String>>("extras")
        val extrasBool = call.argument<Map<String, Boolean>>("extrasBool")
        val clearTask = call.argument<Boolean>("clearTask") ?: false
        val noHistory = call.argument<Boolean>("noHistory") ?: false
        val targetPkg = setPackage ?: componentPkg

        // Content URI is built at most once, and only if a {file.uri} token is used.
        var contentUri: Uri? = null
        fun uriString(): String {
            val u = contentUri
                ?: FileProvider.getUriForFile(
                    this, "$packageName.fileprovider", File(romPath)).also { contentUri = it }
            return u.toString()
        }
        fun sub(s: String): String {
            var r = s.replace("{file.path}", romPath)
            if (r.contains("{file.uri}")) r = r.replace("{file.uri}", uriString())
            return r
        }

        return try {
            val intent = Intent(action ?: Intent.ACTION_VIEW)
            if (componentPkg != null && componentClass != null) {
                intent.component = ComponentName(componentPkg, componentClass)
            }
            if (setPackage != null) intent.setPackage(setPackage)
            if (category != null) intent.addCategory(category)
            if (data != null) {
                val uri = Uri.parse(sub(data))
                if (mimeType != null) intent.setDataAndType(uri, mimeType) else intent.data = uri
            }
            extras?.forEach { (k, v) -> intent.putExtra(k, sub(v)) }
            extrasBool?.forEach { (k, v) -> intent.putExtra(k, v) }
            // Any {file.uri} we handed out needs read access granted to the target.
            contentUri?.let { uri ->
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                targetPkg?.let { grantUriPermission(it, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (clearTask) {
                intent.addFlags(
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            if (noHistory) intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            // Kill any stale background instance first so the emulator boots the
            // new ROM fresh instead of resurfacing (RetroArch black-screens
            // otherwise). No-op when the app isn't already running.
            targetPkg?.let {
                (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                    .killBackgroundProcesses(it)
            }
            startActivity(intent)
            null
        } catch (e: Exception) {
            "${e.javaClass.simpleName}: ${e.message}"
        }
    }

    // Pins a home-screen shortcut that reopens this app with the ROM args, so a
    // later tap re-runs launchRom (re-granting the file URI and rebuilding the
    // per-emulator intent) instead of firing a stale content:// grant directly.
    // Returns null on success, or "ExceptionClass: message" / "unsupported".
    private fun createShortcut(call: io.flutter.plugin.common.MethodCall): String? {
        val romPath = call.argument<String>("romPath")
            ?: return "bad_args: romPath required"
        val pkg = call.argument<String>("package") ?: return "bad_args: package required"
        val kindId = call.argument<String>("kindId") ?: ""
        val consoleId = call.argument<Int>("consoleId") ?: 0
        val label = call.argument<String>("label") ?: "ROM"
        val iconPath = call.argument<String>("iconPath")
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(this))
            return "unsupported: this launcher doesn't allow pinned shortcuts"
        // ROM box art if we were handed a readable image, else the app icon.
        val icon = iconPath?.let { BitmapFactory.decodeFile(it) }
            ?.let { IconCompat.createWithBitmap(it) }
            ?: IconCompat.createWithResource(this, R.mipmap.ic_launcher)
        val launch = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("shortcut_romPath", romPath)
            putExtra("shortcut_package", pkg)
            putExtra("shortcut_kindId", kindId)
            putExtra("shortcut_consoleId", consoleId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        return try {
            val info = ShortcutInfoCompat.Builder(this, "rom_${romPath.hashCode()}")
                .setShortLabel(label)
                .setIcon(icon)
                .setIntent(launch)
                .build()
            ShortcutManagerCompat.requestPinShortcut(this, info, null)
            null
        } catch (e: Exception) {
            "${e.javaClass.simpleName}: ${e.message}"
        }
    }

    // Pre-R relies on requestLegacyExternalStorage in the manifest, so raw paths
    // already work there; only R+ needs the explicit grant.
    private fun hasAllFilesAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
            Environment.isExternalStorageManager()
        else true

    private fun openSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                }
            )
        }
    }
}
