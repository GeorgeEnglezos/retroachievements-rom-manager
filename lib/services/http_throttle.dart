import 'package:http/http.dart' as http;

/// One serialized, rate-limited GET shared by every metadata provider.
///
/// Spaces requests out by [minGap], backs off on HTTP 429 (honoring a
/// `Retry-After` header when present), and serializes concurrent callers so a
/// big scan can't skip the gate.
///
/// Every request is capped by [timeout]. Because calls are serialized, one
/// stalled socket would otherwise hang every request behind it, which during a
/// library sweep reads as the scan freezing on some ROM forever.
///
/// The [http.Client] is injected so the network path is unit-testable; pass
/// zero durations in tests to skip the real waits.
class HttpThrottle {
  final http.Client _client;
  final Map<String, String> _headers;
  final Duration minGap;
  final int maxRetries;
  final Duration retryBackoffBase;
  final Duration timeout;

  HttpThrottle({
    http.Client? client,
    Map<String, String>? headers,
    this.minGap = const Duration(milliseconds: 350),
    this.maxRetries = 4,
    this.retryBackoffBase = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _headers = headers ?? const {};

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _queue = Future.value();

  /// Throttled GET: spaced, backed off on 429, serialized via [_queue].
  /// [timeout] overrides the default cap for this call; multi-MB list
  /// downloads need a longer one than a per-ROM hash lookup.
  Future<http.Response> get(Uri uri,
      {Map<String, String>? headers, Duration? timeout}) {
    final result = _queue.then((_) => _doGet(uri, headers, timeout ?? this.timeout));
    // Keep the chain alive whether this request succeeds or throws.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<http.Response> _doGet(
      Uri uri, Map<String, String>? extra, Duration limit) async {
    final since = DateTime.now().difference(_lastRequest);
    if (since < minGap) await Future.delayed(minGap - since);

    final headers = extra == null ? _headers : {..._headers, ...extra};
    for (var attempt = 0;; attempt++) {
      _lastRequest = DateTime.now();
      // A timed-out request is left to the OS to reap; nothing here holds a
      // socket handle worth cancelling explicitly.
      final response = await _client.get(uri, headers: headers).timeout(limit);
      if (response.statusCode == 429 && attempt < maxRetries) {
        // Honor a Retry-After header if the server sends one, else back off.
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        final wait = retryAfter != null
            ? Duration(seconds: retryAfter)
            : retryBackoffBase * (1 << attempt);
        await Future.delayed(wait);
        continue;
      }
      return response;
    }
  }
}
