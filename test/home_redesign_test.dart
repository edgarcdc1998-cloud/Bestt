import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_player/models/media_item.dart';
import 'package:best_player/models/playback_type.dart';
import 'package:best_player/repositories/authentication_repository.dart';
import 'package:best_player/repositories/catalog_repository.dart';
import 'package:best_player/repositories/library_repository.dart';
import 'package:best_player/screens/epg_screen.dart';
import 'package:best_player/screens/home_screen.dart';
import 'package:best_player/screens/series_detail_screen.dart';
import 'package:best_player/services/app_storage.dart';

void main() {
  late AppStorage storage;
  late AuthenticationRepository auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await AppStorage.getInstance();
    auth = AuthenticationRepository(storage);
  });

  testWidgets('M3U series with a direct URL offers playback without Xtream', (tester) async {
    await auth.loginM3u('https://example.test/list.m3u');
    final library = LibraryRepository(storage);
    await library.init();
    addTearDown(library.dispose);
    await tester.pumpWidget(MaterialApp(home: SeriesDetailScreen(
      series: const MediaItem(id: 'm3u-episode', title: 'Minha série E01',
        streamUrl: 'https://example.test/episode.mp4', type: PlaybackType.series),
      authRepo: auth, libraryRepo: library,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Reproduzir episódio'), findsOneWidget);
    expect(find.text('Nenhum episódio encontrado'), findsNothing);
  });

  testWidgets('failed series request offers retry instead of empty episodes', (tester) async {
    await storage.setString('auth_type', 'xtream');
    await storage.setJson('xtream_config', {
      'serverUrl': 'https://example.test', 'username': 'test', 'password': 'test',
    });
    await auth.init();
    final library = LibraryRepository(storage);
    await library.init();
    addTearDown(library.dispose);
    // Flutter's widget-test HTTP client returns 400, exercising the real
    // XtreamService failure path without contacting a provider.
    await tester.pumpWidget(MaterialApp(home: SeriesDetailScreen(
      series: const MediaItem(id: 's1', title: 'Série indisponível',
        seriesId: '1', streamUrl: '', type: PlaybackType.series),
      authRepo: auth, libraryRepo: library,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Nenhum episódio encontrado'), findsNothing);
  });

  testWidgets('home reacts to watch history recorded through its shared library', (tester) async {
    final catalog = CatalogRepository(auth);
    addTearDown(catalog.dispose);
    await tester.pumpWidget(MaterialApp(home: HomeScreen(authRepo: auth, catalogRepo: catalog)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('EPG'));
    await tester.pumpAndSettle();
    final epg = tester.widget<EpgScreen>(find.byType(EpgScreen));
    final library = epg.libraryRepo;
    Navigator.of(tester.element(find.byType(EpgScreen))).pop();
    await tester.pumpAndSettle();
    await library.addToHistory(const MediaItem(
      id: 'resume-1', title: 'Filme para continuar', streamUrl: 'https://example.test/movie.mp4',
      type: PlaybackType.movie, resumePosition: Duration(minutes: 3), duration: Duration(minutes: 90),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Filme para continuar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
