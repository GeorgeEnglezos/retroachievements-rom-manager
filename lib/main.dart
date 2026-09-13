import 'dart:async';
import 'dart:io';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/setup_wizard.dart';
import 'services/app_mode.dart';
import 'services/play_view.dart';
import 'services/app_theme.dart';
import 'services/display_name.dart';
import 'services/library.dart';
import 'services/library_folder.dart';
import 'services/log_service.dart';
import 'services/pref_keys.dart';
import 'services/ui_scale.dart';
import 'services/single_instance.dart';
import 'theme/ui_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/gamepad_navigator.dart';
import 'widgets/scan_progress_bar.dart';

void main() {
  // Run inside a guarded zone so uncaught async errors are logged as crashes.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Only one desktop instance may run; a second launch exits immediately.
    if (!await SingleInstance.acquire()) {
      exit(0);
    }
    await LogService.init();
    await initNameMode();
    await initCombineSystems();
    await initAppTheme();
    await initUiScale();
    await initAppMode();
    await initPlayView();
    await initLibraryFolder();
    await Library.instance.init();
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool(PrefKeys.setupDone) ?? false;

    // Flutter framework errors (build/layout/paint) → Logs tab as crashes.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // Known Flutter/Windows bug: RawKeyboard asserts when Alt arrives with
      // modifiers:0 (Windows omits the modifier flag on the Alt key itself).
      // Harmless. Keyboard state self-corrects on the next event.
      if (details.exception is AssertionError &&
          details.exceptionAsString().contains('keysPressed')) {
        return;
      }
      LogService.error(
        'FlutterError',
        details.exceptionAsString(),
        err: details.stack,
      );
      previousOnError?.call(details);
    };

    LogService.info('App', 'Retroachievements Rom Manager started');
    // ExcludeSemantics: Flutter's Windows accessibility bridge crashes on
    // route pop while a screen reader is attached. Trade-off: no screen
    // readers. Remove once Flutter ships the engine fix.
    runApp(
      ExcludeSemantics(
        child: DevicePreview(
          enabled: kDebugMode,
          builder: (_) => MyApp(setupDone: setupDone),
        ),
      ),
    );
  }, (error, stack) {
    LogService.error('UncaughtError', error.toString(), err: stack);
  });
}

/// Browser-style zoom for the whole app. Shrinks the logical viewport by
/// [scale] so the UI reflows to the smaller size, then paints it back up to
/// fill the window: zooming in makes everything bigger and rewraps content,
/// rather than just cropping.
class UiZoom extends StatelessWidget {
  final double scale;
  final Widget child;

  const UiZoom({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return child;
    final mq = MediaQuery.of(context);
    final logical = mq.size / scale;
    return MediaQuery(
      // Insets (safe areas, the on-screen keyboard) live in the same scaled
      // space as the size, so divide them too or padded content drifts.
      data: mq.copyWith(
        size: logical,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: logical, child: child),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool setupDone;

  const MyApp({super.key, required this.setupDone});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeListenable,
      builder: (context, theme, _) {
        var themeData = uiTheme(theme.tokens);
        // Debug builds run inside DevicePreview; adopt its simulated device
        // platform so platform-gated layouts (the landscape-phone shell) can be
        // previewed on desktop by picking an Android device in the toolbar.
        // Release never enters here, so the real platform stays untouched.
        // isEnabled guards against the store's async init: on the first frame
        // it is still initializing and DevicePreview.platform would throw
        // "Not initialized". Once init finishes the store notifies, this
        // rebuilds, and the simulated platform is applied.
        if (kDebugMode && DevicePreview.isEnabled(context)) {
          themeData = themeData.copyWith(platform: DevicePreview.platform(context));
        }
        return MaterialApp(
        title: 'Retroachievements Rom Manager',
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.locale(context),
        // Mount the scan progress bar above the Navigator so it renders over
        // any route (home, folder view) while a background sweep runs.
        builder: (context, child) => GamepadNavigator(
          child: ValueListenableBuilder<double>(
            valueListenable: uiScaleListenable,
            builder: (context, scale, _) => UiZoom(
              scale: scale,
              child: Stack(
                children: [
                  DevicePreview.appBuilder(context, child),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(top: false, child: ScanProgressBar()),
                  ),
                ],
              ),
            ),
          ),
        ),
        theme: themeData,
        // Every mode uses the one responsive shell; big picture is that shell in
        // gaming trim, shown full-window and driven by the pad (the separate
        // couch shell was retired). AppShell listens to appModeListenable itself,
        // so a mode flip rebuilds it. Setup always runs first.
        home: setupDone ? const AppShell() : const SetupWizard(),
        );
      },
    );
  }
}
