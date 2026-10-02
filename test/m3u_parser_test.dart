import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/m3u_parser.dart';

void main() {
  group('M3uParser Tests', () {
    test('parses simple M3U content correctly', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="cnn.us" tvg-name="CNN HD" tvg-logo="http://logo.com/cnn.png" group-title="News",CNN USA
http://stream.server.com/live/cnn.m3u8
#EXTINF:-1 tvg-id="espn.us" tvg-name="ESPN" group-title="Sports",ESPN HD
http://stream.server.com/live/espn.ts
''';

      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(2));

      expect(channels[0].name, equals('CNN USA'));
      expect(channels[0].tvgId, equals('cnn.us'));
      expect(channels[0].categoryName, equals('News'));
      expect(channels[0].logoUrl, equals('http://logo.com/cnn.png'));
      expect(channels[0].streamUrl, equals('http://stream.server.com/live/cnn.m3u8'));

      expect(channels[1].name, equals('ESPN HD'));
      expect(channels[1].tvgId, equals('espn.us'));
      expect(channels[1].categoryName, equals('Sports'));
      expect(channels[1].streamUrl, equals('http://stream.server.com/live/espn.ts'));
    });

    test('handles empty or malformed M3U gracefully', () {
      final channels = M3uParser.parse('');
      expect(channels, isEmpty);

      final channels2 = M3uParser.parse('Random string without links');
      expect(channels2, isEmpty);
    });
  });
}
