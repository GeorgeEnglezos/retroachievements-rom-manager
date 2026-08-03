import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';
import 'pref_keys.dart';

/// A published release newer than the one running.
class ReleaseUpdate {
  /// Semantic version without the tag's leading `v`.
  final String version;

  /// Release page to open in the browser.
  final String url;

  const ReleaseUpdate({required this.version, required this.url});
}

/// Looks up the newest stable release on GitHub and compares it with the
/// running build.
///
/// Uses GitHub's `/releases/latest` endpoint, which excludes pre-releases
/// server-side: the repo's rolling `nightly` pre-release is skipped without any
/// client-side filtering, in one request.
///
/// The current version is passed in rather than read from `package_info_plus`
/// so this stays plugin-free and unit-testable; the [http.Client] is injected
/// for the same reason.
abstract final class UpdateCheck {
  static const _repo = 'GeorgeEnglezos/retroachievements-rom-manager';

  /// Where the browser lands when a release carries no page of its own.
  static const releasesPage = 'https://github.com/$_repo/releases';

  static final Uri _latestRelease =
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest');

  static const _timeout = Duration(seconds: 10);

  /// The latest stable release, when it is newer than [currentVersion] and
  /// newer than whatever the user last dismissed. Null otherwise, including on
  /// every failure: an update check is never worth interrupting the app for.
  static Future<ReleaseUpdate?> check({
    required String currentVersion,
    http.Client? client,
  }) async {
    final ownsClient = client == null;
    final c = client ?? http.Client();
    try {
      final response = await c.get(_latestRelease, headers: const {
        'Accept': 'application/vnd.github+json',
        // GitHub answers 403 to requests without a User-Agent.
        'User-Agent': 'retroachievements-rom-manager',
      }).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      if (tag == null || tag.isEmpty) return null;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;

      if (!isNewer(version, currentVersion)) return null;
      final skipped = await _skipped();
      if (skipped != null && !isNewer(version, skipped)) return null;

      LogService.info('UpdateCheck',
          'Update available: v$version (running v$currentVersion)');
      return ReleaseUpdate(
        version: version,
        url: json['html_url'] as String? ?? releasesPage,
      );
    } on TimeoutException {
      return null; // slow or unreachable network
    } on SocketException {
      return null; // offline
    } on http.ClientException {
      return null; // connection dropped mid-request
    } on FormatException catch (e) {
      LogService.warning('UpdateCheck', 'Malformed release payload: $e');
      return null;
    } catch (e) {
      LogService.error('UpdateCheck', 'Update check failed', err: e);
      return null;
    } finally {
      if (ownsClient) c.close();
    }
  }

  /// Records [version] as dismissed, so [check] stays quiet until something
  /// newer than it ships. Callers dismiss from a UI callback and can't await
  /// this, so a failed write is logged here rather than escaping as an
  /// unhandled async error; the only cost is the banner returning next launch.
  static Future<void> skip(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.skippedRelease, version);
    } catch (e) {
      LogService.error('UpdateCheck', 'Could not persist dismissed release',
          err: e);
    }
  }

  static Future<String?> _skipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefKeys.skippedRelease);
  }

  /// Whether [latest] is a later version than [current].
  ///
  /// Compares the first three numeric segments, then pre-release suffixes: a
  /// stable release outranks any pre-release of the same base version, and two
  /// pre-releases compare lexicographically (correct for the zero-padded date
  /// suffixes the nightly workflow produces).
  static bool isNewer(String latest, String current) {
    final a = _segments(latest);
    final b = _segments(current);
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }

    final suffixA = _suffix(latest);
    final suffixB = _suffix(current);
    if (suffixA == suffixB) return false;
    if (suffixA.isEmpty) return true; // stable > pre-release of the same base
    if (suffixB.isEmpty) return false;
    return suffixA.compareTo(suffixB) > 0;
  }

  /// major/minor/patch, zero-padded. A fourth segment some release tags carry
  /// is dropped so it can never read as newer than the app's 3-part version.
  static List<int> _segments(String version) {
    final parts = version.split('-').first.split('.');
    return [
      for (var i = 0; i < 3; i++)
        i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0,
    ];
  }

  static String _suffix(String version) {
    final dash = version.indexOf('-');
    return dash < 0 ? '' : version.substring(dash + 1);
  }
}
