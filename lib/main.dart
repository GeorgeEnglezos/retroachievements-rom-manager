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
import 'services/single_instance.dart';
import 'theme/ui_theme.dart';
import 'widgets/app_shell.dart';
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

class MyApp extends StatelessWidget {
  final bool setupDone;

  const MyApp({super.key, required this.setupDone});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeListenable,
      builder: (context, theme, _) => MaterialApp(
        title: 'Retroachievements Rom Manager',
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.locale(context),
        // Mount the scan progress bar above the Navigator so it renders over
        // any route (home, folder view) while a background sweep runs.
        builder: (context, child) => Stack(
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
        theme: uiTheme(paletteFor(theme)),
        home: setupDone ? const AppShell() : const SetupWizard(),
      ),
    );
  }
}
