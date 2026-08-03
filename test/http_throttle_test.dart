import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rarm/services/http_throttle.dart';

/// Hand-written fake: returns queued responses in order, records requests.
class _FakeClient extends http.BaseClient {
  final List<http.Response> responses;
  int calls = 0;
  final List<http.BaseRequest> requests = [];
  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final r = responses[calls < responses.length ? calls : responses.length - 1];
    calls++;
    return http.StreamedResponse(
      Stream.value(utf8.encode(r.body)),
      r.statusCode,
      headers: r.headers,
      request: request,
    );
  }
}

/// Never answers its first [stallCalls] requests, mimicking a dead socket.
class _StallingClient extends http.BaseClient {
  final int stallCalls;
  int calls = 0;
  _StallingClient({this.stallCalls = 1 << 30});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (calls++ < stallCalls) return Completer<http.StreamedResponse>().future;
    return Future.value(http.StreamedResponse(
        Stream.value(utf8.encode('ok')), 200,
        request: request));
  }
}

// Zero delays so the retry loop runs instantly in tests.
HttpThrottle _throttle(_FakeClient client, {Map<String, String>? headers}) =>
    HttpThrottle(
      client: client,
      headers: headers,
      minGap: Duration.zero,
      retryBackoffBase: Duration.zero,
    );

void main() {
  final uri = Uri.https('example.com', '/x');

  test('returns the 200 response body', () async {
    final client = _FakeClient([http.Response('ok', 200)]);
    final res = await _throttle(client).get(uri);
    expect(res.statusCode, 200);
    expect(res.body, 'ok');
    expect(client.calls, 1);
  });

  test('sends configured default headers', () async {
    final client = _FakeClient([http.Response('ok', 200)]);
    await _throttle(client, headers: {'User-Agent': 'RAROMManager/1.0'}).get(uri);
    expect(client.requests.single.headers['User-Agent'], 'RAROMManager/1.0');
  });

  test('retries after 429 then returns the success', () async {
    final client = _FakeClient([
      http.Response('slow down', 429),
      http.Response('ok', 200),
    ]);
    final res = await _throttle(client).get(uri);
    expect(res.statusCode, 200);
    expect(client.calls, 2);
  });

  // A stalled socket used to hang the whole scan: no timeout anywhere, so one
  // dead request froze the sweep at whatever ROM it was on.
  test('times out a stalled request instead of hanging', () async {
    final t = HttpThrottle(
      client: _StallingClient(),
      minGap: Duration.zero,
      retryBackoffBase: Duration.zero,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(t.get(uri), throwsA(isA<TimeoutException>()));
  });

  test('a timed-out request does not wedge the ones behind it', () async {
    final client = _StallingClient(stallCalls: 1);
    final t = HttpThrottle(
      client: client,
      minGap: Duration.zero,
      retryBackoffBase: Duration.zero,
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(t.get(uri), throwsA(isA<TimeoutException>()));
    expect((await t.get(uri)).statusCode, 200);
  });

  test('gives up after maxRetries and returns the last 429', () async {
    final client = _FakeClient([http.Response('nope', 429)]);
    final t = HttpThrottle(
      client: client,
      minGap: Duration.zero,
      retryBackoffBase: Duration.zero,
      maxRetries: 2,
    );
    final res = await t.get(uri);
    expect(res.statusCode, 429);
    expect(client.calls, 3); // initial + 2 retries
  });
}
