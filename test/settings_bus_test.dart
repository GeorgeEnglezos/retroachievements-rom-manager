import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/display_name.dart';
import 'package:rarm/services/scan_settings.dart';
import 'package:rarm/services/settings_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every settings write reaches the one bus screens listen to', () async {
    var fired = 0;
    void listener() => fired++;
    settingsChanged.addListener(listener);
    addTearDown(() => settingsChanged.removeListener(listener));

    await ScanSettings.setIgnoredFolders('BIOS');
    expect(fired, 1);

    // Used to publish nothing, so a console change never reached Home.
    await ScanSettings.setFolderConsoleOverride('snes', 3);
    expect(fired, 2);

    await ScanSettings.addExcludedFiles([r'C:\roms\snes\bad.sfc']);
    expect(fired, 3);

    nameModeListenable.save(NameMode.folderName);
    expect(fired, 4);

    // Prefs with no listenable of their own (username, API key).
    publishSettingsChange();
    expect(fired, 5);
  });
}
