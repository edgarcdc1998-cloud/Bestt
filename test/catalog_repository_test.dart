import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/models/channel.dart';
import 'package:best_player/repositories/authentication_repository.dart';
import 'package:best_player/repositories/catalog_repository.dart';
import 'package:best_player/services/app_storage.dart';
import 'package:best_player/services/http_client.dart';
import 'package:best_player/services/playlist_service.dart';
import 'package:http/http.dart' as http;

class FakeAppStorage implements AppStorage {
  final Map<String, dynamic> _data = {};

  @override
  T? getModel<T>(String key, T Function(Map<String, dynamic>) fromJson) => null;

  @override
  List<T> getModelList<T>(String key, T Function(Map<String, dynamic>) fromJson) => [];

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Map<String, dynamic>? getJsonMap(String key, {Map<String, dynamic>? defaultValue}) => defaultValue;

  @override
  List<dynamic>? getJsonList(String key, {List<dynamic>? defaultValue}) => defaultValue;

  @override
  Future<void> setJson(String key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

class FakeHttpClient extends HttpClient {
  final String m3uResponse;

  FakeHttpClient(this.m3uResponse);

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response(m3uResponse, 200);
  }
}

void main() {
  group('CatalogRepository Category Indexing Tests (ETAPA 4B)', () {
    const testM3u = '''#EXTM3U
#EXTINF:-1 group-title="News",CNN
http://stream.com/cnn.m3u8
#EXTINF:-1 group-title="News",BBC
http://stream.com/bbc.m3u8
#EXTINF:-1 group-title="Sports",ESPN
http://stream.com/espn.m3u8
#EXTINF:-1,Canal Sem Categoria
http://stream.com/geral.m3u8
''';

    test('1. Indexa categorias corretamente no carregamento M3U', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      await authRepo.loginM3u('http://playlist.com/list.m3u');

      final httpClient = FakeHttpClient(testM3u);
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await catalogRepo.loadCatalog();

      expect(catalogRepo.channels.length, equals(4));
      expect(catalogRepo.liveCategories.length, equals(3)); // News, Sports, Geral

      // Category list order preserved
      expect(catalogRepo.liveCategories[0]['category_name'], equals('News'));
      expect(catalogRepo.liveCategories[1]['category_name'], equals('Sports'));
      expect(catalogRepo.liveCategories[2]['category_name'], equals('Geral'));

      // Fast category query
      final newsChannels = await catalogRepo.getChannelsByCategory('News');
      expect(newsChannels.length, equals(2));
      expect(newsChannels[0].name, equals('CNN'));
      expect(newsChannels[1].name, equals('BBC'));

      final sportsChannels = await catalogRepo.getChannelsByCategory('Sports');
      expect(sportsChannels.length, equals(1));
      expect(sportsChannels[0].name, equals('ESPN'));

      final generalChannels = await catalogRepo.getChannelsByCategory('Geral');
      expect(generalChannels.length, equals(1));
      expect(generalChannels[0].name, equals('Canal Sem Categoria'));

      final allChannels = await catalogRepo.getChannelsByCategory('all');
      expect(allChannels.length, equals(4));
    });

    test('2. Categoria inexistente retorna lista vazia sem lançar exceção', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      await authRepo.loginM3u('http://playlist.com/list.m3u');

      final httpClient = FakeHttpClient(testM3u);
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await catalogRepo.loadCatalog();

      final nonExistent = await catalogRepo.getChannelsByCategory('NonExistentCategory');
      expect(nonExistent, isEmpty);
    });
  });
}
