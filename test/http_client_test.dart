import 'package:flutter_test/flutter_test.dart';
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
  });
}
