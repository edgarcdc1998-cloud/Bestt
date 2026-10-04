import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class HttpClient {
  final http.Client _client;
  final Duration timeout;
  final String userAgent;
  final Duration Function(int attempt) _retryDelay;

  HttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.userAgent = 'BestPlayer/1.0 (Android; IPTV)',
    Duration Function(int attempt)? retryDelay,
  })  : _client = client ?? http.Client(),
        _retryDelay = retryDelay ?? ((attempt) => Duration(milliseconds: 500 * attempt));

  Map<String, String> _buildHeaders([Map<String, String>? customHeaders]) {
    final headers = {
      'User-Agent': userAgent,
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await _client
            .get(uri, headers: _buildHeaders(headers))
            .timeout(timeout);
        return response;
      } on SocketException {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      } on TimeoutException {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      } catch (e) {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      }
    }
  }

  /// Streaming GET request for large payloads (e.g. M3U playlists) without full body materialization (ETAPA 4D).
  Future<http.StreamedResponse> getStream(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final request = http.Request('GET', uri);
        request.headers.addAll(_buildHeaders(headers));
        final response = await _client.send(request).timeout(timeout);
        return response;
      } on SocketException {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      } on TimeoutException {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      } catch (e) {
        if (attempts > maxRetries) rethrow;
        await Future.delayed(_retryDelay(attempts));
      }
    }
  }

  Future<dynamic> getJson(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    final response = await get(uri, headers: headers, maxRetries: maxRetries);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(utf8.decode(response.bodyBytes));
      } catch (_) {
        return json.decode(response.body);
      }
    } else {
      throw HttpException('HTTP error ${response.statusCode}', uri: uri);
    }
  }

  void close() {
    _client.close();
  }
}
