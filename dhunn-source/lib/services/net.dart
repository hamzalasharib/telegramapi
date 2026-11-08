import 'dart:convert';
import 'dart:io';

/// ONE shared, keep-alive HTTP client for every lyrics / cover
/// lookup (v2.22 speed fix). The old code built a brand-new
/// HttpClient for EVERY request — a fresh DNS + TLS handshake per
/// song — and then walked the library strictly one song at a time
/// with artificial sleeps between songs. That, not the user's
/// internet, was why bulk downloads crawled. This client reuses
/// connections across requests and allows several in flight.
class Net {
  static HttpClient? _client;

  static HttpClient get client => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 25)
    ..maxConnectionsPerHost = 8;

  /// GET with a hard total timeout; returns (statusCode, body).
  static Future<(int, String)> get(Uri u, {required String ua}) async {
    final req = await client.getUrl(u).timeout(const Duration(seconds: 12));
    req.headers.set(HttpHeaders.userAgentHeader, ua);
    final resp = await req.close().timeout(const Duration(seconds: 12));
    final body = await resp
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 12));
    return (resp.statusCode, body);
  }
}
