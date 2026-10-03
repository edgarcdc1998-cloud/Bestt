import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:best_player/services/http_client.dart';
import 'package:best_player/services/playlist_service.dart';

class MockStreamHttpClient extends HttpClient {
  final Stream<List<int>> byteStream;
  final int statusCode;

  MockStreamHttpClient({
    required this.byteStream,
    this.statusCode = 200,
  });

  @override
  Future<http.StreamedResponse> getStream(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    return http.StreamedResponse(
      byteStream,
      statusCode,
    );
  }
}

void main() {
  group('PlaylistService HTTP Streaming Tests (ETAPA 4D)', () {
    test('1. Resposta M3U simples via streaming', () async {
      const m3u = '#EXTM3U\n#EXTINF:-1 tvg-id="c1",Canal 1\nhttp://stream.com/1.m3u8\n';
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Canal 1'));
      expect(channels.first.streamUrl, equals('http://stream.com/1.m3u8'));
    });

    test('2. Múltiplas linhas processadas via stream', () async {
      const m3u = '''#EXTM3U
#EXTINF:-1 group-title="News",CNN
http://stream.com/cnn.m3u8
#EXTINF:-1 group-title="Sports",ESPN
http://stream.com/espn.m3u8
''';
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(2));
      expect(channels[0].name, equals('CNN'));
      expect(channels[1].name, equals('ESPN'));
    });

    test('3. Suporta quebras de linha CRLF (\r\n) no stream', () async {
      const m3u = "#EXTM3U\r\n#EXTINF:-1,Canal CRLF\r\nhttp://stream.com/crlf.m3u8\r\n";
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Canal CRLF'));
    });

    test('4. Ausência de newline final no término do stream', () async {
      const m3u = '#EXTM3U\n#EXTINF:-1,Canal Sem Newline\nhttp://stream.com/nonewline.m3u8';
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(1));
      expect(channels.first.name, equals('Canal Sem Newline'));
    });

    test('5. Decodificação UTF-8 padrão no stream', () async {
      const m3u = '#EXTM3U\n#EXTINF:-1 group-title="Música",Sertanejo & Pagode\nhttp://stream.com/pagode.m3u8\n';
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.first.categoryName, equals('Música'));
      expect(channels.first.name, equals('Sertanejo & Pagode'));
    });

    test('6. Caractere UTF-8 multibyte dividido entre chunks', () async {
      // String com caractere 'ã' e 'é' (multibyte UTF-8)
      const fullText = '#EXTM3U\n#EXTINF:-1,São Paulo Épico\nhttp://stream.com/sp.m3u8\n';
      final bytes = utf8.encode(fullText);

      // Divide os bytes exatamente no meio de um caractere UTF-8
      final splitIndex = bytes.indexOf(utf8.encode('ã')[0]) + 1;
      final chunk1 = bytes.sublist(0, splitIndex);
      final chunk2 = bytes.sublist(splitIndex);

      final controller = StreamController<List<int>>();
      final client = MockStreamHttpClient(byteStream: controller.stream);
      final service = PlaylistService(httpClient: client);

      final future = service.fetchPlaylist('http://playlist.com/list.m3u');
      controller.add(chunk1);
      controller.add(chunk2);
      await controller.close();

      final channels = await future;
      expect(channels.first.name, equals('São Paulo Épico'));
    });

    test('7. Linha dividida entre múltiplos chunks TCP', () async {
      final chunk1 = utf8.encode('#EXTM3U\n#EXTINF:-1 tvg-id="c1" group-title="Notí');
      final chunk2 = utf8.encode('cias",Jornal da Band\nhttp://stream.com/band.m3u8\n');

      final controller = StreamController<List<int>>();
      final client = MockStreamHttpClient(byteStream: controller.stream);
      final service = PlaylistService(httpClient: client);

      final future = service.fetchPlaylist('http://playlist.com/list.m3u');
      controller.add(chunk1);
      controller.add(chunk2);
      await controller.close();

      final channels = await future;
      expect(channels.first.categoryName, equals('Notícias'));
      expect(channels.first.name, equals('Jornal da Band'));
    });

    test('8. CRLF dividido entre chunks (\r no chunk 1 e \n no chunk 2)', () async {
      final chunk1 = utf8.encode('#EXTM3U\r\n#EXTINF:-1,Canal Split\r');
      final chunk2 = utf8.encode('\nhttp://stream.com/split.m3u8\r\n');

      final controller = StreamController<List<int>>();
      final client = MockStreamHttpClient(byteStream: controller.stream);
      final service = PlaylistService(httpClient: client);

      final future = service.fetchPlaylist('http://playlist.com/list.m3u');
      controller.add(chunk1);
      controller.add(chunk2);
      await controller.close();

      final channels = await future;
      expect(channels.first.name, equals('Canal Split'));
    });

    test('9. Status HTTP 200 processa com sucesso', () async {
      const m3u = '#EXTM3U\n#EXTINF:-1,Canal OK\nhttp://stream.com/ok.m3u8\n';
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(m3u)),
        statusCode: 200,
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(1));
    });

    test('10. Status HTTP não-2xx lança exceção com código de status', () async {
      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode('Not Found')),
        statusCode: 404,
      );
      final service = PlaylistService(httpClient: client);

      expect(
        () => service.fetchPlaylist('http://playlist.com/notfound.m3u'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('404'),
        )),
      );
    });

    test('11. Stream vazio retorna lista vazia de canais', () async {
      final client = MockStreamHttpClient(
        byteStream: Stream.value(<int>[]),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/empty.m3u');
      expect(channels, isEmpty);
    });

    test('12. Erro durante o stream propaga exceção e não retorna dados parciais silenciosos', () async {
      final controller = StreamController<List<int>>();
      final client = MockStreamHttpClient(byteStream: controller.stream);
      final service = PlaylistService(httpClient: client);

      final futureExpect = expectLater(
        service.fetchPlaylist('http://playlist.com/error.m3u'),
        throwsA(isA<Exception>()),
      );

      controller.add(utf8.encode('#EXTM3U\n#EXTINF:-1,Canal 1\nhttp://stream.com/1.m3u8\n'));
      controller.addError(Exception('Conexão resetada pelo servidor'));
      await controller.close();

      await futureExpect;
    });

    test('13. Preserva rigorosamente a ordem dos canais entregues por streaming', () async {
      final buffer = StringBuffer('#EXTM3U\n');
      for (int i = 1; i <= 20; i++) {
        buffer.writeln('#EXTINF:-1,Canal $i');
        buffer.writeln('http://stream.com/ch_$i.m3u8');
      }

      final client = MockStreamHttpClient(
        byteStream: Stream.value(utf8.encode(buffer.toString())),
      );
      final service = PlaylistService(httpClient: client);

      final channels = await service.fetchPlaylist('http://playlist.com/list.m3u');
      expect(channels.length, equals(20));
      for (int i = 0; i < 20; i++) {
        expect(channels[i].name, equals('Canal ${i + 1}'));
      }
    });
  });
}
