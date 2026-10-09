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

  Widget _liveTab() {
    final channels = widget.catalogRepo.channels;
    return CustomScrollView(key: const PageStorageKey('live'), slivers: [
      SliverToBoxAdapter(child: _heading('Ao vivo', '${channels.length} canais no seu catálogo')),
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

  Widget _mediaTab(List<MediaItem> items, {required bool series}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(series ? 'Séries' : 'Filmes', '${items.length} títulos para descobrir'),
      if (widget.catalogRepo.loadError != null) _catalogErrorBanner(),
      if (widget.catalogRepo.isLoading) const LinearProgressIndicator(),
      Expanded(child: items.isEmpty
        ? CatalogMessage(icon: series ? Icons.video_library_outlined : Icons.movie_outlined,
            title: series ? 'Nenhuma série encontrada' : 'Nenhum filme encontrado',
            message: widget.catalogRepo.isLoading ? 'Carregando seu catálogo…' : 'O conteúdo da sua lista aparecerá aqui.')
        : MediaCatalogGrid(items: items, storageKey: series ? 'series' : 'movies',
            onTap: (media) => _openMedia(media, playlist: items))),
    ],
  );

  Widget _favoritesTab() {
    final channels = _libraryRepo!.favoriteChannels;
    final media = _libraryRepo!.favoriteMedia;
    return CustomScrollView(key: const PageStorageKey('favorites'), slivers: [
      SliverToBoxAdapter(child: _heading('Favoritos', 'Seu conteúdo sempre por perto')),
      if (channels.isEmpty && media.isEmpty)
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
        _liveTab(), _mediaTab(widget.catalogRepo.movies, series: false),
        _mediaTab(widget.catalogRepo.series, series: true), _favoritesTab(),
      ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (index) => setState(() => _currentNavIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Ao vivo'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: 'Filmes'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Séries'),
          NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Favoritos'),
        ],
      ),
    );
  }
}
