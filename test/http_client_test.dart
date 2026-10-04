import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:best_player/services/http_client.dart';

void main() {
  group('HttpClient Tests', () {
    test('Instance creation with custom User-Agent and timeout', () {
      final client = HttpClient(
        timeout: const Duration(seconds: 10),
        userAgent: 'CustomTestAgent/1.0',
      );
      expect(client.timeout.inSeconds, equals(10));
      expect(client.userAgent, equals('CustomTestAgent/1.0'));
      client.close();
    });

    test('get combines default and custom headers', () async {
      late http.BaseRequest capturedRequest;
      final client = HttpClient(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('ok', 200);
        }),
        userAgent: 'CustomTestAgent/1.0',
      );

      final response = await client.get(
        Uri.parse('https://example.com/playlist'),
        headers: {'X-Playlist-Id': 'abc'},
      );

      expect(response.statusCode, equals(200));
      expect(capturedRequest.headers['user-agent'], equals('CustomTestAgent/1.0'));
      expect(capturedRequest.headers['accept'], equals('*/*'));
      expect(capturedRequest.headers['connection'], equals('keep-alive'));
      expect(capturedRequest.headers['x-playlist-id'], equals('abc'));
      client.close();
    });

    test('get retries socket failures up to maxRetries', () async {
      var attempts = 0;
      final client = HttpClient(
        client: MockClient((_) async {
          attempts++;
          if (attempts < 3) throw const SocketException('temporary failure');
          return http.Response('ok', 200);
        }),
        retryDelay: (_) => Duration.zero,
      );

      final response = await client.get(
        Uri.parse('https://example.com/playlist'),
        maxRetries: 2,
      );

      expect(response.statusCode, equals(200));
      expect(attempts, equals(3));
      client.close();
    });

    test('get propagates the failure after exhausting retries', () async {
      var attempts = 0;
      final client = HttpClient(
        client: MockClient((_) async {
          attempts++;
          throw const SocketException('persistent failure');
        }),
        retryDelay: (_) => Duration.zero,
      );

      await expectLater(
        client.get(Uri.parse('https://example.com/playlist'), maxRetries: 1),
        throwsA(isA<SocketException>()),
      );
      expect(attempts, equals(2));
      client.close();
    });

    test('getStream preserves request headers and response stream', () async {
      late http.BaseRequest capturedRequest;
      final client = HttpClient(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('stream body', 200);
        }),
      );

      final response = await client.getStream(
        Uri.parse('https://example.com/playlist'),
        headers: {'X-Playlist-Id': 'abc'},
      );

      expect(response.statusCode, equals(200));
      expect(capturedRequest.headers['user-agent'], equals('BestPlayer/1.0 (Android; IPTV)'));
      expect(capturedRequest.headers['x-playlist-id'], equals('abc'));
      expect(await response.stream.bytesToString(), equals('stream body'));
      client.close();
    });
  });
}
