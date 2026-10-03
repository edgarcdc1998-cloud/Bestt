import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/m3u_parser.dart';

void main() {
  group('M3uParser Tests (ETAPA 4B)', () {
    test('1. Suporta quebras de linha LF (\n) padrão', () {
      const m3u = '#EXTM3U\n#EXTINF:-1 tvg-id="c1" group-title="News",CNN\nhttp://server.com/cnn.m3u8\n';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('CNN'));
      expect(channels.first.categoryName, equals('News'));
    });

    test('2. Suporta quebras de linha CRLF (\r\n) do Windows', () {
      const m3u = "#EXTM3U\r\n#EXTINF:-1 tvg-id=\"c1\" group-title=\"Sports\",ESPN\r\nhttp://server.com/espn.m3u8\r\n";
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('ESPN'));
      expect(channels.first.categoryName, equals('Sports'));
      expect(channels.first.streamUrl, equals('http://server.com/espn.m3u8'));
    });

    test('3. Ignora linhas vazias e espaços extras', () {
      const m3u = '''

#EXTM3U

   #EXTINF:-1 tvg-id="c1" group-title="News",BBC News   

http://server.com/bbc.m3u8


''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('BBC News'));
    });

    test('4. Ignora linhas inválidas e comentários não-EXTINF', () {
      const m3u = '''
#EXTM3U
# Comentário arbitrário
INVALID LINE HERE
#EXTINF:-1 tvg-id="c1",Canal 1
http://server.com/c1.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Canal 1'));
    });

    test('5. Extrai múltiplas categorias corretamente', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Notícias",Canal A
http://server.com/a.m3u8
#EXTINF:-1 group-title="Esportes",Canal B
http://server.com/b.m3u8
#EXTINF:-1 group-title="Filmes",Canal C
http://server.com/c.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(3));
      expect(channels[0].categoryName, equals('Notícias'));
      expect(channels[1].categoryName, equals('Esportes'));
      expect(channels[2].categoryName, equals('Filmes'));
    });

    test('6. Categoria ausente assume fallback para Geral', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="c1",Canal Sem Categoria
http://server.com/stream.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.categoryName, equals('Geral'));
      expect(channels.first.categoryId, equals('Geral'));
    });

    test('7. Nome do canal contendo vírgulas extras é preservado após a última vírgula', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="c1" group-title="News",Notícias, 24h, HD Brasil
http://server.com/stream.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('HD Brasil'));
    });

    test('8. Preserva acentuação UTF-8 em group-title e nomes', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Variedades & Música Épica",Globo São Paulo HD
http://server.com/globo.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.categoryName, equals('Variedades & Música Épica'));
      expect(channels.first.name, equals('Globo São Paulo HD'));
    });

    test('9. Atributos ausentes recebem fallbacks coerentes', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1,Globo
http://server.com/stream.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Globo'));
      expect(channels.first.tvgId, isNull);
      expect(channels.first.logoUrl, isNull);
      expect(channels.first.id, equals('channel_1'));
    });

    test('10. Atributos com valores vazios são tratados como nulos/fallback', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="" tvg-logo="" group-title="",SBT HD
http://server.com/sbt.m3u8
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(1));
      expect(channels.first.tvgId, isNull);
      expect(channels.first.logoUrl, isNull);
      expect(channels.first.categoryName, equals('Geral'));
    });

    test('11. Suporta protocolos http, https, rtmp e rtsp', () {
      const m3u = '''
#EXTM3U
#EXTINF:-1,HTTP Channel
http://server.com/live1.m3u8
#EXTINF:-1,HTTPS Channel
https://server.com/live2.m3u8
#EXTINF:-1,RTMP Channel
rtmp://server.com/live3
#EXTINF:-1,RTSP Channel
rtsp://server.com/live4
''';
      final channels = M3uParser.parse(m3u);
      expect(channels.length, equals(4));
      expect(channels[0].streamUrl, equals('http://server.com/live1.m3u8'));
      expect(channels[1].streamUrl, equals('https://server.com/live2.m3u8'));
      expect(channels[2].streamUrl, equals('rtmp://server.com/live3'));
      expect(channels[3].streamUrl, equals('rtsp://server.com/live4'));
    });

    test('12. Preserva rigorosamente a ordem original dos canais', () {
      final buffer = StringBuffer('#EXTM3U\n');
      for (int i = 1; i <= 50; i++) {
        buffer.writeln('#EXTINF:-1 tvg-id="c_$i",Canal $i');
        buffer.writeln('http://server.com/ch_$i.m3u8');
      }

      final channels = M3uParser.parse(buffer.toString());
      expect(channels.length, equals(50));
      for (int i = 0; i < 50; i++) {
        expect(channels[i].name, equals('Canal ${i + 1}'));
        expect(channels[i].streamUrl, equals('http://server.com/ch_${i + 1}.m3u8'));
      }
    });

    test('13. Teste de escala moderada (500 canais)', () {
      final buffer = StringBuffer('#EXTM3U\n');
      for (int i = 1; i <= 500; i++) {
        final category = i % 2 == 0 ? 'Esportes' : 'Filmes';
        buffer.writeln('#EXTINF:-1 tvg-id="c_$i" tvg-name="CN $i" group-title="$category",Canal $i');
        buffer.writeln('https://stream.server.com/ch_$i.ts');
      }

      final channels = M3uParser.parse(buffer.toString());
      expect(channels.length, equals(500));
      expect(channels.first.name, equals('Canal 1'));
      expect(channels.last.name, equals('Canal 500'));
    });
  });
}
