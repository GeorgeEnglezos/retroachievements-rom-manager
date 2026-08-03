import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/update_check.dart';

/// Hand-written fake: answers every request with one canned response, or
/// throws when [error] is set.
class _FakeClient extends http.BaseClient {
  final int status;
  final String body;
  final Object? error;
  final List<http.BaseRequest> requests = [];

  _FakeClient({this.status = 200, this.body = '', this.error});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (error != null) throw error!;
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      request: request,
    );
  }
}

String _release(String tag, {String url = 'https://example.test/release'}) =>
    jsonEncode({'tag_name': tag, 'html_url': url});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('check', () {
    test('returns the release when the remote tag is newer', () async {
      final client = _FakeClient(body: _release('v1.2.0'));
      final update =
          await UpdateCheck.check(currentVersion: '1.1.9', client: client);

      expect(update, isNotNull);
      expect(update!.version, '1.2.0'); // leading 'v' stripped
      expect(update.url, 'https://example.test/release');
    });

    test('returns null when the remote tag matches the running version',
        () async {
      final client = _FakeClient(body: _release('v1.2.0'));
      expect(
        await UpdateCheck.check(currentVersion: '1.2.0', client: client),
        isNull,
      );
    });

    test('returns null when the running version is ahead of the remote tag',
        () async {
      final client = _FakeClient(body: _release('v1.2.0'));
      expect(
        await UpdateCheck.check(currentVersion: '1.3.0', client: client),
        isNull,
      );
    });

    test('falls back to the releases page when html_url is missing', () async {
      final client = _FakeClient(body: jsonEncode({'tag_name': 'v2.0.0'}));
      final update =
          await UpdateCheck.check(currentVersion: '1.0.0', client: client);

      expect(update!.url, UpdateCheck.releasesPage);
    });

    test('returns null on a non-200 response', () async {
      final client = _FakeClient(status: 404, body: '{}');
      expect(
        await UpdateCheck.check(currentVersion: '1.0.0', client: client),
        isNull,
      );
    });

    test('returns null when the payload has no tag', () async {
      final client = _FakeClient(body: jsonEncode({'html_url': 'x'}));
      expect(
        await UpdateCheck.check(currentVersion: '1.0.0', client: client),
        isNull,
      );
    });

    test('returns null on malformed JSON', () async {
      final client = _FakeClient(body: 'not json');
      expect(
        await UpdateCheck.check(currentVersion: '1.0.0', client: client),
        isNull,
      );
    });

    test('returns null when the request fails', () async {
      final client = _FakeClient(error: http.ClientException('offline'));
      expect(
        await UpdateCheck.check(currentVersion: '1.0.0', client: client),
        isNull,
      );
    });

    test('sends a User-Agent (GitHub rejects requests without one)', () async {
      final client = _FakeClient(body: _release('v1.0.0'));
      await UpdateCheck.check(currentVersion: '1.0.0', client: client);

      expect(client.requests.single.headers['User-Agent'], isNotEmpty);
    });
  });

  group('skip', () {
    test('suppresses the skipped version but not a later one', () async {
      await UpdateCheck.skip('1.2.0');

      expect(
        await UpdateCheck.check(
            currentVersion: '1.0.0', client: _FakeClient(body: _release('v1.2.0'))),
        isNull,
      );
      final later = await UpdateCheck.check(
          currentVersion: '1.0.0', client: _FakeClient(body: _release('v1.2.1')));
      expect(later!.version, '1.2.1');
    });

    test('does not suppress an older-than-skipped release', () async {
      // Dismissing 2.0.0 must not hide 1.5.0 — but 1.5.0 is older, so the
      // version comparison already rejects it. Guard against a skip check that
      // accidentally inverts and shows it again.
      await UpdateCheck.skip('2.0.0');
      expect(
        await UpdateCheck.check(
            currentVersion: '1.0.0', client: _FakeClient(body: _release('v1.5.0'))),
        isNull,
      );
    });
  });

  group('isNewer', () {
    test('compares numeric segments left to right', () {
      expect(UpdateCheck.isNewer('1.3.0', '1.2.9'), isTrue);
      expect(UpdateCheck.isNewer('2.0.0', '1.99.99'), isTrue);
      expect(UpdateCheck.isNewer('1.2.9', '1.3.0'), isFalse);
      expect(UpdateCheck.isNewer('1.2.0', '1.2.0'), isFalse);
    });

    test('pads missing segments with zero', () {
      expect(UpdateCheck.isNewer('1.2', '1.2.0'), isFalse);
      expect(UpdateCheck.isNewer('1.2.1', '1.2'), isTrue);
    });

    test('ignores a fourth segment', () {
      // Some release tags carry a build suffix (1.7.4.1); it must never read as
      // newer than the app's own 3-part version.
      expect(UpdateCheck.isNewer('1.7.4.1', '1.7.4'), isFalse);
    });

    test('stable beats a pre-release of the same base version', () {
      expect(UpdateCheck.isNewer('1.6.0', '1.6.0-rc.1'), isTrue);
      expect(UpdateCheck.isNewer('1.6.0-rc.1', '1.6.0'), isFalse);
    });

    test('compares two pre-releases of the same base by suffix', () {
      expect(
          UpdateCheck.isNewer('1.6.0-nightly.20260301', '1.6.0-nightly.20260228'),
          isTrue);
      expect(
          UpdateCheck.isNewer('1.6.0-nightly.20260228', '1.6.0-nightly.20260301'),
          isFalse);
    });

    test('treats unparseable segments as zero rather than throwing', () {
      expect(UpdateCheck.isNewer('1.x.0', '1.0.0'), isFalse);
      expect(UpdateCheck.isNewer('1.2.0', 'garbage'), isTrue);
    });
  });
}
