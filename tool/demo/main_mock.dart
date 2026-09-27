import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rarm/main.dart' as app;
import 'package:rarm/services/console_map.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screenshot mode on your real library: the normal app and data, narrowed to
/// one manufacturer's systems and shown under a fake RetroAchievements name.
/// Windows only. From the repo root:
///
///   flutter run -d windows --profile -t tool/demo/main_mock.dart
///
/// `--dart-define=ONLY=Nintendo` picks another manufacturer (the names are
/// ConsoleMap's), `ONLY=` shows everything, and `DEMO_WIZARD=true` opens the
/// first-run wizard. Profile mode, because debug wraps the app in the
/// DevicePreview frame.
///
/// Settings are a copy held in memory, so the real settings file is never
/// written. RA calls still go to the real site under your real name; only the
/// name, avatar and other systems' unlocks are swapped out of what comes back.
/// App data (scans, artwork cache) is the real one, so avoid destructive
/// actions. Close the real app first; only one instance runs.
const fakeName = 'PixelPilgrim';
const only = String.fromEnvironment('ONLY', defaultValue: 'Sony');

/// Whether a console, by RA's console name, belongs to the [only] maker.
bool shownConsole(String? consoleName) =>
    only.isEmpty ||
    ConsoleMap.manufacturerForId(
          ConsoleMap.consoleNames.entries
              .where((e) => e.value == consoleName)
              .firstOrNull
              ?.key,
        ) ==
        only;

Future<void> main() async {
  final base = p.join(
    Platform.environment['APPDATA']!,
    'com.georgeenglezos',
    'RA ROM Manager',
  );
  final real =
      jsonDecode(
            File(p.join(base, 'shared_preferences.json')).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final prefs = {
    for (final e in real.entries)
      e.key.replaceFirst('flutter.', ''): e.value is List
          ? (e.value as List).cast<String>()
          : e.value,
  };
  final realName = prefs[PrefKeys.raUsername] as String;

  // Hide every other manufacturer's folders through the app's own
  // ignored-folders filter.
  if (only.isNotEmpty) {
    final root = prefs[PrefKeys.lastFolder] as String;
    final hidden = [
      for (final d in Directory(root).listSync().whereType<Directory>())
        if (ConsoleMap.manufacturerForId(
              ConsoleMap.idForFolder(p.basename(d.path)),
            ) !=
            only)
          p.basename(d.path),
    ];
    prefs['ignored_folders'] = [
      prefs['ignored_folders'] as String? ?? '',
      ...hidden,
    ].join(', ');
  }
  // Paths under the home folder (emulators, playlists) carry the Windows user
  // name; stored as plain text and as JSON inside other prefs.
  final home = Platform.environment['USERPROFILE']!;
  const neutral = r'C:\Users\Player';
  for (final k in prefs.keys.toList()) {
    final v = prefs[k];
    if (v is String) {
      prefs[k] = v
          .replaceAll(home, neutral)
          .replaceAll(
            home.replaceAll(r'\', r'\\'),
            neutral.replaceAll(r'\', r'\\'),
          );
    }
  }
  prefs[PrefKeys.raUsername] = fakeName;
  prefs[PrefKeys.setupDone] = !const bool.fromEnvironment('DEMO_WIZARD');
  // Drop the cached real avatar and unlock history; both refetch through the
  // client below.
  prefs
    ..remove(PrefKeys.raAvatarPath)
    ..remove(PrefKeys.raAvatarVersion)
    ..remove('recent_unlocks_cache');
  // The in-memory store is meant for tests; here it keeps the real settings
  // file untouched.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(prefs.cast<String, Object>());

  // Created outside the zone below, so it stays a real network client.
  final handle = aliasedRa(network: http.Client(), realName: realName);
  http.runWithClient(app.main, () => MockClient(handle));
}

/// Passes every request to [network], asking RA as [realName] wherever the
/// app asks as [fakeName], and scrubs the answers: the profile names the fake
/// user with a drawn avatar, and unlock and completion lists keep only
/// [shownConsole] games.
Future<http.Response> Function(http.Request) aliasedRa({
  required http.Client network,
  required String realName,
}) => (req) async {
  var url = req.url;
  if (url.path.startsWith('/UserPic/$fakeName')) {
    return http.Response.bytes(
      _avatar(),
      200,
      headers: {'content-type': 'image/png'},
    );
  }
  if (url.queryParameters.values.contains(fakeName)) {
    url = url.replace(
      queryParameters: {
        for (final e in url.queryParameters.entries)
          e.key: e.value == fakeName ? realName : e.value,
      },
    );
  }
  final res = await network.get(url, headers: req.headers);
  if (!url.path.startsWith('/API/') || res.statusCode != 200) return res;

  Object? body = jsonDecode(res.body);
  switch (url.path) {
    case '/API/API_GetUserProfile.php':
      body = {
        ...body as Map,
        'User': fakeName,
        'UserPic': '/UserPic/$fakeName.png',
      };
    case '/API/API_GetAchievementsEarnedBetween.php':
      body = [
        for (final a in body as List)
          if (shownConsole(a['ConsoleName'] as String?)) a,
      ];
    case '/API/API_GetUserCompletionProgress.php':
      final results = [
        for (final g in (body as Map)['Results'] as List)
          if (shownConsole(g['ConsoleName'] as String?)) g,
      ];
      body = {...body, 'Results': results, 'Count': results.length};
    default:
      return res;
  }
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
};

/// Plain initial-on-colour avatar for the fake name.
List<int> _avatar() {
  final image = img.Image(width: 128, height: 128);
  img.fill(image, color: img.ColorRgb8(0x3B, 0x6E, 0xA8));
  img.drawString(
    image,
    fakeName[0],
    font: img.arial48,
    x: 50,
    y: 38,
    color: img.ColorRgb8(255, 255, 255),
  );
  return img.encodePng(image);
}
