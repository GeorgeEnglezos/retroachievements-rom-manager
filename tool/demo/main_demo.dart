import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:rarm/main.dart' as app;
import 'package:rarm/services/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_ra.dart';

/// Screenshot mode: the real app showing your real, already-fetched library
/// (minus the franchises `export_demo_data.dart` filters out) under a demo
/// username. Windows only. From the repo root:
///
///   dart run tool/demo/export_demo_data.dart      # once, or to refresh
///   flutter run -d windows --profile -t tool/demo/main_demo.dart
///
/// Profile mode, because debug wraps the app in the DevicePreview frame. Add
/// `--dart-define=DEMO_WIZARD=true` to start at the first-run wizard, and pick
/// Later on its scan step: a rescan would treat the placeholder ROMs as new.
///
/// Nothing touches your real data: settings and the API key live in memory,
/// files go under `C:\Users\Public\RARM Demo` (no username in screenshots), and
/// RA API calls are answered by [DemoRa]. Artwork still loads from the real
/// site. Close the real app first; only one instance runs.
Future<void> main() async {
  final root = p.join(
    Platform.environment['PUBLIC'] ?? Directory.systemTemp.path,
    'RARM Demo',
  );
  PathProviderPlatform.instance = _DemoPaths(root);

  final data =
      jsonDecode(
            File(
              p.join('tool', 'demo', 'demo_library.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  // Seeded fresh each launch, already scanned and fetched, in the app's own
  // system-file format (the snapshot is a filtered copy of the real files).
  final roms = p.join(root, 'roms');
  final systemsDir = Directory(p.join(root, 'support', 'data', 'systems'));
  if (systemsDir.existsSync()) systemsDir.deleteSync(recursive: true);
  systemsDir.createSync(recursive: true);
  final systems = (data['systems'] as List).cast<Map<String, dynamic>>();
  for (final (i, s) in systems.indexed) {
    final systemPath = p.join(roms, s['folder'] as String);
    final games = [
      for (final g in (s['games'] as List).cast<Map<String, dynamic>>())
        {...g, 'filePath': p.join(systemPath, g['relPath'] as String)}
          ..remove('relPath'),
    ];
    for (final g in games) {
      _placeholder(
        g['filePath'] as String,
        (g['fileSize'] as num?)?.toInt() ?? 0,
      );
    }
    File(p.join(systemsDir.path, 'demo$i.json')).writeAsStringSync(
      jsonEncode({
        'version': 1,
        'systemId': 'demo$i',
        'systemPath': systemPath,
        'consoleId': s['consoleId'],
        'games': games,
        'dismissedDuplicatePairs': const [],
      }),
    );
  }

  // The in-memory stores are meant for tests; here they keep the demo off
  // the real settings file and credential vault.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    for (final e
        in (data['prefs'] as Map<String, dynamic>? ?? const {}).entries)
      e.key: e.value is List
          ? (e.value as List).cast<String>()
          : e.value as Object,
    PrefKeys.raUsername: data['username'] as String,
    PrefKeys.lastFolder: roms,
    PrefKeys.setupDone: !const bool.fromEnvironment('DEMO_WIZARD'),
  });
  // ignore: invalid_use_of_visible_for_testing_member
  FlutterSecureStorage.setMockInitialValues({PrefKeys.raApiKey: 'demo'});

  // Created outside the zone below, so it stays a real network client.
  final ra = DemoRa(data, artwork: http.Client());
  // Every http.Client the app creates inside this zone (RA API calls and the
  // artwork cache) is the fake one.
  http.runWithClient(app.main, () => MockClient(ra.handle));
}

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _createFile = _kernel32
    .lookupFunction<
      IntPtr Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer,
        Uint32,
        Uint32,
        IntPtr,
      ),
      int Function(Pointer<Utf16>, int, int, Pointer, int, int, int)
    >('CreateFileW');
final _deviceIoControl = _kernel32
    .lookupFunction<
      Int32 Function(
        IntPtr,
        Uint32,
        Pointer,
        Uint32,
        Pointer,
        Uint32,
        Pointer<Uint32>,
        Pointer,
      ),
      int Function(
        int,
        int,
        Pointer,
        int,
        Pointer,
        int,
        Pointer<Uint32>,
        Pointer,
      )
    >('DeviceIoControl');
final _closeHandle = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');

/// A stand-in ROM that reports the real file's [size] but takes no disk space
/// (an NTFS sparse file), so the app's size checks and Storage tab see the real
/// library. Left empty if the drive can't do sparse files, rather than filling
/// it with hundreds of GB of zeros.
void _placeholder(String path, int size) {
  final file = File(path);
  if (file.existsSync() && file.lengthSync() == size) return;
  file.createSync(recursive: true);
  final name = path.toNativeUtf16();
  final returned = calloc<Uint32>();
  var sparse = false;
  try {
    // GENERIC_WRITE, OPEN_EXISTING, then FSCTL_SET_SPARSE.
    final h = _createFile(name, 0x40000000, 0, nullptr, 3, 0, 0);
    if (h != -1) {
      sparse =
          _deviceIoControl(
            h,
            0x900C4,
            nullptr,
            0,
            nullptr,
            0,
            returned,
            nullptr,
          ) !=
          0;
      _closeHandle(h);
    }
  } finally {
    calloc.free(name);
    calloc.free(returned);
  }
  if (!sparse) return;
  final raf = file.openSync(mode: FileMode.append);
  raf.truncateSync(size);
  raf.closeSync();
}

class _DemoPaths extends PathProviderPlatform {
  final String root;
  _DemoPaths(this.root);

  // Created on demand: the app assumes these exist, as the real ones do.
  Future<String?> _dir(String name) async =>
      (await Directory(p.join(root, name)).create(recursive: true)).path;

  @override
  Future<String?> getApplicationSupportPath() => _dir('support');
  @override
  Future<String?> getApplicationDocumentsPath() => _dir('documents');
  @override
  Future<String?> getApplicationCachePath() => _dir('cache');
  @override
  Future<String?> getTemporaryPath() => _dir('temp');
  @override
  Future<String?> getDownloadsPath() => _dir('downloads');
}
