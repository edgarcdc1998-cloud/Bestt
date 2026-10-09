import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_player/app.dart';
import 'package:best_player/models/channel.dart';
import 'package:best_player/models/media_item.dart';
import 'package:best_player/models/playback_type.dart';
import 'package:best_player/repositories/authentication_repository.dart';
import 'package:best_player/repositories/catalog_repository.dart';
import 'package:best_player/repositories/library_repository.dart';
import 'package:best_player/services/app_storage.dart';

// UI-only fixtures; no demonstration content is shipped in the application.
class PreviewCatalog extends CatalogRepository {
  PreviewCatalog(super.auth);
  @override
  List<Channel> get channels => const [
    Channel(id: 'news', name: 'Notícias ao vivo', streamUrl: 'https://example.test/live', categoryName: 'Informação'),
    Channel(id: 'sport', name: 'Esportes em destaque', streamUrl: 'https://example.test/sport', categoryName: 'Esportes'),
    Channel(id: 'culture', name: 'Cultura e documentários', streamUrl: 'https://example.test/culture', categoryName: 'Cultura'),
  ];
  @override
  List<MediaItem> get movies => const [
    MediaItem(id: 'm1', title: 'Uma viagem além do horizonte', streamUrl: 'https://example.test/movie', type: PlaybackType.movie),
    MediaItem(id: 'm2', title: 'Noite na cidade', streamUrl: 'https://example.test/movie2', type: PlaybackType.movie),
    MediaItem(id: 'm3', title: 'Entre montanhas', streamUrl: 'https://example.test/movie3', type: PlaybackType.movie),
    MediaItem(id: 'm4', title: 'Memórias de um verão', streamUrl: 'https://example.test/movie4', type: PlaybackType.movie),
  ];
  @override
  List<MediaItem> get series => const [
    MediaItem(id: 's1', title: 'Histórias do amanhã', streamUrl: '', seriesId: '1', type: PlaybackType.series),
    MediaItem(id: 's2', title: 'O último farol', streamUrl: '', seriesId: '2', type: PlaybackType.series),
  ];
}

void main() {
  test('first favorite and history insert work with empty preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final library = LibraryRepository(await AppStorage.getInstance());
    await library.init();
    addTearDown(library.dispose);
    const channel = Channel(id: 'c1', name: 'Canal', streamUrl: 'https://example.test/live');
    const movie = MediaItem(id: 'm1', title: 'Filme', streamUrl: 'https://example.test/movie', type: PlaybackType.movie);
    await library.toggleChannelFavorite(channel);
    await library.toggleMediaFavorite(movie);
    await library.addToHistory(movie);
    expect(library.isChannelFavorite('c1'), isTrue);
    expect(library.isMediaFavorite('m1'), isTrue);
    expect(library.watchHistory.single.id, 'm1');
    await library.toggleChannelFavorite(channel);
    await library.toggleMediaFavorite(movie);
    expect(library.favoriteChannels, isEmpty);
    expect(library.favoriteMedia, isEmpty);
  });

  for (final size in [const Size(320, 568), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('catalog tabs fit ${size.width}x${size.height} with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      final storage = await AppStorage.getInstance();
      final auth = AuthenticationRepository(storage);
      await auth.loginM3u('https://example.test/playlist');
      final catalog = PreviewCatalog(auth);
      addTearDown(auth.dispose);
      addTearDown(catalog.dispose);
      await tester.pumpWidget(BestPlayerApp(authRepo: auth, catalogRepo: catalog));
      await tester.pumpAndSettle();
      for (final label in ['Ao vivo', 'Filmes', 'Séries', 'Favoritos']) {
        await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label must fit $size');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  // Opt-in visual exports, run with --update-goldens. These are review
  // screenshots, not baselines used to claim regression coverage.
  if (const bool.fromEnvironment('CAPTURE_PREVIEWS')) {
    testWidgets('export actual Flutter screens for visual review', (tester) async {
      await tester.runAsync(() async {
        final root = Platform.environment['FLUTTER_ROOT'];
        if (root == null) throw StateError('FLUTTER_ROOT is required for preview fonts');
        final font = File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
        final bytes = await font.readAsBytes();
        final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = await AppStorage.getInstance();
      final auth = AuthenticationRepository(storage);
      await auth.loginM3u('https://example.test/playlist');
      final library = LibraryRepository(storage);
      await library.init();
      await library.addToHistory(const MediaItem(id: 'resume', title: 'Uma viagem além do horizonte',
        streamUrl: 'https://example.test/movie', type: PlaybackType.movie,
        resumePosition: Duration(minutes: 24), duration: Duration(minutes: 90)));
      await library.toggleChannelFavorite(const Channel(id: 'news', name: 'Notícias ao vivo', streamUrl: 'https://example.test/live'));
      library.dispose();
      final catalog = PreviewCatalog(auth);
      addTearDown(auth.dispose);
      addTearDown(catalog.dispose);
      const previewKey = Key('screen-preview');
      await tester.pumpWidget(RepaintBoundary(key: previewKey,
        child: BestPlayerApp(authRepo: auth, catalogRepo: catalog)));
      await tester.pumpAndSettle();
      final tabs = {'Ao vivo': 'live', 'Filmes': 'movies', 'Séries': 'series', 'Favoritos': 'favorites'};
      for (final entry in tabs.entries) {
        await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(entry.key)));
        await tester.pumpAndSettle();
        await expectLater(find.byKey(previewKey), matchesGoldenFile('../build/previews/${entry.value}.png'));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
