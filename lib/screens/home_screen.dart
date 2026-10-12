import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/library_repository.dart';
import '../services/app_storage.dart';
import '../widgets/catalog_widgets.dart';
import 'epg_screen.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'player/playback_navigation.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;

  const HomeScreen({super.key, required this.authRepo, required this.catalogRepo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  LibraryRepository? _libraryRepo;
  bool _initializationFailed = false;
  String _liveQuery = '';
  String _movieQuery = '';
  String _seriesQuery = '';

  @override
  void initState() {
    super.initState();
    widget.catalogRepo.addListener(_refresh);
    _initLibrary();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogRepo != widget.catalogRepo) {
      oldWidget.catalogRepo.removeListener(_refresh);
      widget.catalogRepo.addListener(_refresh);
    }
  }

  Future<void> _initLibrary() async {
    try {
      final storage = await AppStorage.getInstance();
      if (!mounted) return;
      final library = LibraryRepository(storage);
      await library.init();
      if (!mounted) {
        library.dispose();
        return;
      }
      library.addListener(_refresh);
      setState(() {
        _libraryRepo = library;
        _initializationFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initializationFailed = true);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.catalogRepo.removeListener(_refresh);
    _libraryRepo?.removeListener(_refresh);
    _libraryRepo?.dispose();
    super.dispose();
  }

  Future<void> _playMedia(MediaItem media, {List<MediaItem>? playlist}) async {
    await openPlaybackRoute(context,
      builder: (_) => PlayerScreen(media: media, playlist: playlist,
        libraryRepository: _libraryRepo!),
      library: _libraryRepo!, onReturn: _refresh);
  }

  Future<void> _openMedia(MediaItem media, {List<MediaItem>? playlist}) async {
    if (media.isSeries && media.streamUrl.trim().isEmpty) {
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(series: media,
          authRepo: widget.authRepo, libraryRepo: _libraryRepo!),
      ));
      _refresh();
    } else {
      await _playMedia(media, playlist: playlist);
    }
  }

  MediaItem _channelMedia(Channel channel) => MediaItem(
    id: channel.id, title: channel.name, streamUrl: channel.streamUrl,
    type: PlaybackType.live, posterUrl: channel.logoUrl,
    categoryId: channel.categoryId, categoryName: channel.categoryName,
    streamId: channel.streamId,
  );

  void _playChannel(Channel channel, List<Channel> channels) {
    _playMedia(_channelMedia(channel), playlist: channels.map(_channelMedia).toList());
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
        letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.4)),
    ]),
  );

  Widget _continueWatching() {
    final items = _libraryRepo!.continueWatching;
    if (items.isEmpty) return const SizedBox.shrink();
    final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text('Continuar assistindo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      SizedBox(height: 122 + 58 * textScale, child: ListView.separated(
        key: const PageStorageKey('continue-watching'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final media = items[index];
          final resume = media.resumePosition ?? Duration.zero;
          final total = media.duration?.inMilliseconds ?? 0;
          final progress = total > 0 ? (resume.inMilliseconds / total).clamp(0.0, 1.0) : null;
          return SizedBox(width: 200, child: Material(
            color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: () => _openMedia(media), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 100, child: Stack(fit: StackFit.expand, children: [
                  CatalogArtwork(url: media.backdropUrl ?? media.posterUrl),
                  const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white)),
                  if (progress != null) Positioned(left: 0, right: 0, bottom: 0,
                    child: LinearProgressIndicator(value: progress, minHeight: 4,
                      backgroundColor: Colors.white24, color: Colors.redAccent)),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600))),
                Padding(padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Text('${resume.inMinutes} min assistidos',
                    style: const TextStyle(fontSize: 11, color: Colors.white60))),
              ],
            )),
          ));
        },
      )),
      const SizedBox(height: 20),
    ]);
  }

  Widget _channelTile(Channel channel, List<Channel> playlist, {bool favorite = false}) =>
    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Material(
      color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(
          width: 48, height: 48,
          child: CatalogArtwork(url: channel.logoUrl, icon: Icons.live_tv, fit: BoxFit.contain))),
        title: Text(channel.name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(channel.categoryName ?? 'Ao vivo', maxLines: 1,
          overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        trailing: IconButton(
          tooltip: favorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
          icon: Icon(favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: favorite ? Colors.redAccent : Colors.white54),
          onPressed: () => _libraryRepo!.toggleChannelFavorite(channel),
        ),
        onTap: () => _playChannel(channel, playlist),
      ),
    ));

  Widget _catalogErrorBanner() => Material(
    color: const Color(0xFF382022),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Icon(Icons.wifi_off_outlined, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.catalogRepo.loadError!,
          style: const TextStyle(fontSize: 13))),
        TextButton(
          onPressed: widget.catalogRepo.isLoading
              ? null
              : () => widget.catalogRepo.loadCatalog(),
          child: const Text('Tentar novamente'),
        ),
      ]),
    ),
  );


  // Curated sections use the existing provider catalog, never demo titles.
  Widget _homeRail(String title, List<MediaItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Text(title, style: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      SizedBox(height: 226, child: ListView.separated(
        key: PageStorageKey('home-rail-$title'),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length > 12 ? 12 : items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final item = items[index];
          return SizedBox(width: 130, child: MediaPosterCard(
            media: item, onTap: () => _openMedia(item, playlist: items)));
        },
      )),
    ]);
  }

  Widget _homeTab() {
    final movies = widget.catalogRepo.movies;
    final series = widget.catalogRepo.series;
    final featured = movies.isNotEmpty ? movies.first
        : (series.isNotEmpty ? series.first : null);
    return CustomScrollView(
      key: const PageStorageKey('home'),
      slivers: [
        if (widget.catalogRepo.loadError != null)
          SliverToBoxAdapter(child: _catalogErrorBanner()),
        if (widget.catalogRepo.isLoading)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (featured != null)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClipRRect(borderRadius: BorderRadius.circular(18),
              child: SizedBox(height: 252, child: Stack(
                fit: StackFit.expand, children: [
                  CatalogArtwork(url: featured.backdropUrl ?? featured.posterUrl),
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xEE0C0C0F)],
                      stops: [0.22, 1.0]))),
                  Positioned(left: 16, right: 16, bottom: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                        Text(featured.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openMedia(featured,
                            playlist: featured.isSeries ? series : movies),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Assistir agora')),
                      ])),
                ])))),
          )),
        SliverToBoxAdapter(child: _continueWatching()),
        SliverToBoxAdapter(child: _homeRail('Filmes em destaque', movies)),
        SliverToBoxAdapter(child: _homeRail('Séries populares', series)),
        if (featured == null && !widget.catalogRepo.isLoading)
          const SliverFillRemaining(hasScrollBody: false,
            child: CatalogMessage(
              icon: Icons.movie_filter_outlined,
              title: 'Seu catálogo aparecerá aqui',
              message: 'Carregue sua lista para explorar filmes e séries.')),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _liveTab() {
    final allChannels = widget.catalogRepo.channels;
    final channels = allChannels.where((channel) =>
      channel.name.toLowerCase().contains(_liveQuery.toLowerCase())).toList();
    return CustomScrollView(key: const PageStorageKey('live'), slivers: [
      SliverToBoxAdapter(child: _heading('TV ao vivo', '${allChannels.length} canais no seu catálogo')),
      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar canais',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
          onChanged: (value) => setState(() => _liveQuery = value),
        ))),
      SliverToBoxAdapter(child: _continueWatching()),
      if (widget.catalogRepo.loadError != null)
        SliverToBoxAdapter(child: _catalogErrorBanner()),
      if (widget.catalogRepo.isLoading)
        const SliverToBoxAdapter(child: LinearProgressIndicator()),
      if (channels.isEmpty && !widget.catalogRepo.isLoading)
        const SliverFillRemaining(hasScrollBody: false, child: CatalogMessage(
          icon: Icons.live_tv, title: 'Nenhum canal encontrado',
          message: 'Os canais da sua lista aparecerão aqui.'))
      else
        SliverList(delegate: SliverChildBuilderDelegate((_, index) =>
          _channelTile(channels[index], channels,
            favorite: _libraryRepo!.isChannelFavorite(channels[index].id)),
          childCount: channels.length)),
      const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ]);
  }

  Widget _mediaTab(List<MediaItem> items, {required bool series}) {
    final query = series ? _seriesQuery : _movieQuery;
    final visible = items.where((item) =>
      item.title.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading(series ? 'Séries' : 'Filmes', '${items.length} títulos para descobrir'),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          decoration: InputDecoration(
            hintText: series ? 'Buscar séries' : 'Buscar filmes',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
          onChanged: (value) => setState(() {
            if (series) { _seriesQuery = value; } else { _movieQuery = value; }
          }),
        )),
      if (widget.catalogRepo.loadError != null) _catalogErrorBanner(),
      if (widget.catalogRepo.isLoading) const LinearProgressIndicator(),
      Expanded(child: visible.isEmpty
        ? CatalogMessage(icon: series ? Icons.video_library_outlined : Icons.movie_outlined,
            title: query.isNotEmpty ? 'Nenhum resultado para sua busca'
              : (series ? 'Nenhuma série encontrada' : 'Nenhum filme encontrado'),
            message: widget.catalogRepo.isLoading ? 'Carregando seu catálogo…'
              : 'Confira sua busca ou sua lista de conteúdos.')
        : MediaCatalogGrid(items: visible, storageKey: series ? 'series' : 'movies',
            onTap: (media) => _openMedia(media, playlist: visible))),
    ]);
  }

  Widget _favoritesTab() {
    final channels = _libraryRepo!.favoriteChannels;
    final media = _libraryRepo!.favoriteMedia;
    return CustomScrollView(key: const PageStorageKey('favorites'), slivers: [
      SliverToBoxAdapter(child: _heading('Biblioteca', 'Seus favoritos e conteúdos para continuar')),
      SliverToBoxAdapter(child: _continueWatching()),
      if (channels.isNotEmpty || media.isNotEmpty)
        const SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text('Minha lista', style: TextStyle(fontSize: 19,
            fontWeight: FontWeight.w800)))),
      if (channels.isEmpty && media.isEmpty && _libraryRepo!.continueWatching.isEmpty)
        const SliverFillRemaining(hasScrollBody: false, child: CatalogMessage(
          icon: Icons.star_outline_rounded, title: 'Sua lista começa aqui',
          message: 'Toque na estrela de um canal ou conteúdo para encontrá-lo aqui.')),
      SliverList(delegate: SliverChildBuilderDelegate((_, index) =>
        _channelTile(channels[index], channels, favorite: true), childCount: channels.length)),
      SliverList(delegate: SliverChildBuilderDelegate((_, index) {
        final item = media[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(
            width: 48, height: 64, child: CatalogArtwork(url: item.posterUrl))),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.isSeries ? 'Série' : 'Filme', style: const TextStyle(color: Colors.white60)),
          trailing: IconButton(tooltip: 'Remover dos favoritos',
            icon: const Icon(Icons.star_rounded, color: Colors.redAccent),
            onPressed: () => _libraryRepo!.toggleMediaFavorite(item)),
          onTap: () => _openMedia(item),
        );
      }, childCount: media.length)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_libraryRepo == null) {
      return Scaffold(body: _initializationFailed
        ? CatalogMessage(icon: Icons.error_outline, title: 'Não foi possível abrir sua biblioteca',
            message: 'Tente novamente para carregar seus favoritos e histórico.',
            onRetry: () { setState(() => _initializationFailed = false); _initLibrary(); })
        : const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('BEST PLAYER', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        actions: [
          IconButton(icon: const Icon(Icons.view_timeline_outlined), tooltip: 'EPG',
            onPressed: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => EpgScreen(
                channels: widget.catalogRepo.channels, authRepo: widget.authRepo,
                libraryRepo: _libraryRepo!)));
              _refresh();
            }),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sair', onPressed: () async {
            await widget.authRepo.logout();
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen(
              authRepo: widget.authRepo, catalogRepo: widget.catalogRepo)));
          }),
        ],
      ),
      body: SafeArea(top: false, child: IndexedStack(index: _currentNavIndex, children: [
        _homeTab(), _liveTab(), _mediaTab(widget.catalogRepo.movies, series: false),
        _mediaTab(widget.catalogRepo.series, series: true), _favoritesTab(),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (index) => setState(() => _currentNavIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Ao vivo'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: 'Filmes'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.bookmark_border_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Biblioteca'),
        ],
      ),
    );
  }
}
