import 'dart:convert';
import '../models/channel.dart';
import 'http_client.dart';
import 'm3u_parser.dart';

class PlaylistService {
  final HttpClient _httpClient;

  PlaylistService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  /// Fetches an M3U playlist via HTTP streaming, decoding lines incrementally without loading full body string (ETAPA 4D).
  Future<List<Channel>> fetchPlaylist(String url) async {
    final uri = Uri.parse(url);
    final response = await _httpClient.getStream(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final lines = <String>[];
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        lines.add(line);
      }
      return M3uParser.parseLines(lines);
    } else {
      throw Exception('Falha ao baixar lista M3U. Código de status: ${response.statusCode}');
    }
  }
}
