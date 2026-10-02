import '../models/channel.dart';
import 'http_client.dart';
import 'm3u_parser.dart';

class PlaylistService {
  final HttpClient _httpClient;

  PlaylistService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  Future<List<Channel>> fetchPlaylist(String url) async {
    final uri = Uri.parse(url);
    final response = await _httpClient.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return M3uParser.parse(response.body);
    } else {
      throw Exception('Falha ao baixar lista M3U. Código de status: ${response.statusCode}');
    }
  }
}
