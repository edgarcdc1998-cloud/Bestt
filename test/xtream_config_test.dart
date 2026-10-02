import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/models/xtream_config.dart';

void main() {
  group('XtreamConfig Tests', () {
    test('sanitizes URL correctly', () {
      final config1 = XtreamConfig(serverUrl: 'http://example.com:8080/', username: 'user', password: 'pass');
      expect(config1.sanitizedServerUrl, equals('http://example.com:8080'));

      final config2 = XtreamConfig(serverUrl: 'example.com:8080', username: 'user', password: 'pass');
      expect(config2.sanitizedServerUrl, equals('http://example.com:8080'));
    });

    test('generates correct stream URLs', () {
      final config = XtreamConfig(serverUrl: 'http://iptv.server:8000', username: 'alice', password: 'secret');
      expect(config.liveStreamUrl(1234), equals('http://iptv.server:8000/live/alice/secret/1234.ts'));
      expect(config.movieStreamUrl(5678, extension: 'mkv'), equals('http://iptv.server:8000/movie/alice/secret/5678.mkv'));
      expect(config.seriesStreamUrl(9999), equals('http://iptv.server:8000/series/alice/secret/9999.mp4'));
    });

    test('serialization and deserialization', () {
      final config = XtreamConfig(serverUrl: 'http://iptv.server:8000', username: 'alice', password: 'secret');
      final json = config.toJson();
      final restored = XtreamConfig.fromJson(json);

      expect(restored.serverUrl, equals(config.serverUrl));
      expect(restored.username, equals(config.username));
      expect(restored.password, equals(config.password));
    });
  });
}
