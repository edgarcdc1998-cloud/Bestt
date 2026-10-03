import 'dart:async';
import 'dart:convert';
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

class ControllableFakeHttpClient extends HttpClient {
  final Map<String, Completer<String>> _urlCompleters = {};
  final Map<String, String> _urlResponses = {};

  void setupUrlResponse(String url, String response) {
    _urlResponses[url] = response;
  }

  Completer<String> setupAsyncUrl(String url) {
    final completer = Completer<String>();
    _urlCompleters[url] = completer;
    return completer;
  }

  @override
  Future<http.StreamedResponse> getStream(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) async {
    final urlStr = uri.toString();
    if (_urlCompleters.containsKey(urlStr)) {
      final responseBody = await _urlCompleters[urlStr]!.future;
      return http.StreamedResponse(
        Stream.value(utf8.encode(responseBody)),
        200,
      );
    }

    final body = _urlResponses[urlStr] ?? '#EXTM3U\n';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
    );
  }
}

void main() {
  group('CatalogRepository Generation Token & Concurrency Tests (ETAPA 5)', () {
    const m3uA = '''#EXTM3U
#EXTINF:-1 group-title="Notícias",Canal A1
http://stream.com/a1.m3u8
#EXTINF:-1 group-title="Notícias",Canal A2
http://stream.com/a2.m3u8
''';

    const m3uB = '''#EXTM3U
#EXTINF:-1 group-title="Esportes",Canal B1
http://stream.com/b1.m3u8
#EXTINF:-1 group-title="Esportes",Canal B2
http://stream.com/b2.m3u8
''';

    const m3uC = '''#EXTM3U
#EXTINF:-1 group-title="Filmes",Canal C1
http://stream.com/c1.m3u8
''';

    test('TESTE 1 — Chamada única carrega dados e índices perfeitamente', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      await authRepo.loginM3u('http://server.com/listA.m3u');

      final httpClient = ControllableFakeHttpClient();
      httpClient.setupUrlResponse('http://server.com/listA.m3u', m3uA);
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      expect(catalogRepo.isLoading, isFalse);
      await catalogRepo.loadCatalog();

      expect(catalogRepo.isLoading, isFalse);
      expect(catalogRepo.channels.length, equals(2));
      expect(catalogRepo.channels[0].name, equals('Canal A1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Notícias'));

      final news = await catalogRepo.getChannelsByCategory('Notícias');
      expect(news.length, equals(2));
    });

    test('TESTE 2 — Segunda chamada vence (A começa, B começa, B termina primeiro, A termina depois)', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      // Start Load A (Generation 1)
      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog();
      expect(catalogRepo.catalogGeneration, equals(1));

      // Start Load B (Generation 2)
      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog();
      expect(catalogRepo.catalogGeneration, equals(2));

      // Complete B FIRST
      completerB.complete(m3uB);
      await futureB;

      // State is B
      expect(catalogRepo.channels.length, equals(2));
      expect(catalogRepo.channels[0].name, equals('Canal B1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Esportes'));

      // Now complete slow A LATER
      completerA.complete(m3uA);
      await futureA;

      // State MUST STILL BE B (A was discarded by Generation Token)
      expect(catalogRepo.channels.length, equals(2));
      expect(catalogRepo.channels[0].name, equals('Canal B1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Esportes'));

      final sports = await catalogRepo.getChannelsByCategory('Esportes');
      expect(sports.length, equals(2));
      final news = await catalogRepo.getChannelsByCategory('Notícias');
      expect(news, isEmpty);
    });

    test('TESTE 3 — Primeira chamada termina primeiro, depois segunda termina (catálogo == B)', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog();

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog();

      // Complete A first
      completerA.complete(m3uA);
      await futureA;

      // Complete B second
      completerB.complete(m3uB);
      await futureB;

      // Final state is B
      expect(catalogRepo.channels[0].name, equals('Canal B1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Esportes'));
    });

    test('TESTE 4 — Três gerações (A, B, C com ordem de conclusão B, A, C -> catálogo == C)', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final completerC = httpClient.setupAsyncUrl('http://server.com/listC.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog(); // Gen 1

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog(); // Gen 2

      await authRepo.loginM3u('http://server.com/listC.m3u');
      final futureC = catalogRepo.loadCatalog(); // Gen 3

      // Order of completion: B, A, C
      completerB.complete(m3uB);
      await futureB;

      completerA.complete(m3uA);
      await futureA;

      completerC.complete(m3uC);
      await futureC;

      // Final state MUST be C
      expect(catalogRepo.channels.length, equals(1));
      expect(catalogRepo.channels[0].name, equals('Canal C1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Filmes'));

      final movies = await catalogRepo.getChannelsByCategory('Filmes');
      expect(movies.length, equals(1));
    });

    test('TESTE 5 — Erro de geração obsoleta não destrói estado de geração mais recente', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog(); // Gen 1

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog(); // Gen 2

      // Complete B successfully
      completerB.complete(m3uB);
      await futureB;

      // Fail A afterwards with error
      completerA.completeError(Exception('Server A Timeout 504'));
      await futureA;

      // State MUST remain valid B
      expect(catalogRepo.channels.length, equals(2));
      expect(catalogRepo.channels[0].name, equals('Canal B1'));
      expect(catalogRepo.isLoading, isFalse);
    });

    test('TESTE 6 — Erro da geração atual desliga loading e preserva contrato', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog();
      expect(catalogRepo.isLoading, isTrue);

      completerA.completeError(Exception('Connection Refused'));
      await futureA;

      expect(catalogRepo.isLoading, isFalse);
    });

    test('TESTE 7 — Loading: término de geração antiga não desliga loading de geração nova ativa', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog(); // Gen 1
      expect(catalogRepo.isLoading, isTrue);

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog(); // Gen 2
      expect(catalogRepo.isLoading, isTrue);

      // Complete A while B is still running
      completerA.complete(m3uA);
      await futureA;

      // isLoading MUST STILL BE TRUE because Gen 2 (B) is active!
      expect(catalogRepo.isLoading, isTrue);

      // Now complete B
      completerB.complete(m3uB);
      await futureB;

      // Now loading turns false
      expect(catalogRepo.isLoading, isFalse);
    });

    test('TESTE 8 — Três gerações com erros e sucessos (B sucesso, A erro, C sucesso -> final C)', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final completerC = httpClient.setupAsyncUrl('http://server.com/listC.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog(); // Gen 1

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog(); // Gen 2

      await authRepo.loginM3u('http://server.com/listC.m3u');
      final futureC = catalogRepo.loadCatalog(); // Gen 3

      // B succeeds
      completerB.complete(m3uB);
      await futureB;

      // A fails with socket error
      completerA.completeError(Exception('Socket reset'));
      await futureA;

      // C succeeds
      completerC.complete(m3uC);
      await futureC;

      // State is C
      expect(catalogRepo.channels.length, equals(1));
      expect(catalogRepo.channels[0].name, equals('Canal C1'));
      expect(catalogRepo.liveCategories.first['category_name'], equals('Filmes'));
    });

    test('TESTE 9 — Geração mais recente mantém canais, categorias e índices atomicamente consistentes', () async {
      final storage = FakeAppStorage();
      final authRepo = AuthenticationRepository(storage);
      final httpClient = ControllableFakeHttpClient();
      final completerA = httpClient.setupAsyncUrl('http://server.com/listA.m3u');
      final completerB = httpClient.setupAsyncUrl('http://server.com/listB.m3u');
      final playlistService = PlaylistService(httpClient: httpClient);

      final catalogRepo = CatalogRepository(
        authRepo,
        playlistService: playlistService,
      );

      await authRepo.loginM3u('http://server.com/listA.m3u');
      final futureA = catalogRepo.loadCatalog();

      await authRepo.loginM3u('http://server.com/listB.m3u');
      final futureB = catalogRepo.loadCatalog();

      // Finish B
      completerB.complete(m3uB);
      await futureB;

      // Finish A
      completerA.complete(m3uA);
      await futureA;

      // Query categories
      final sports = await catalogRepo.getChannelsByCategory('Esportes');
      final news = await catalogRepo.getChannelsByCategory('Notícias');
      final all = await catalogRepo.getChannelsByCategory('all');

      expect(sports.length, equals(2));
      expect(news.length, equals(0)); // Never contains category A
      expect(all.length, equals(2));
      expect(catalogRepo.liveCategories.length, equals(1));
      expect(catalogRepo.liveCategories[0]['category_name'], equals('Esportes'));
    });
  });
}
