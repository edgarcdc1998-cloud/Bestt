import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/library_repository.dart';
import '../services/app_storage.dart';
import '../widgets/catalog_widgets.dart';
import 'player_screen.dart';
import 'player/playback_navigation.dart';
import 'series_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;

  const HomeScreen({super.key, required this.authRepo, required this.catalogRepo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  bool _wasBackgrounded = false;
  bool _refreshingOnResume = false;
  LibraryRepository? _libraryRepo;
  bool _initializationFailed = false;
  String _liveQuery = '';
  String _movieQuery = '';
  String _seriesQuery = '';
  String? _movieCategory;
  String? _seriesCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.catalogRepo.addListener(_refresh);
    _initLibrary();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _refreshCatalogOnResume();
    }
  }

  Future<void> _refreshCatalogOnResume() async {
    if (_refreshingOnResume || !widget.authRepo.isAuthenticated) return;
    _refreshingOnResume = true;
    try {
      final storage = await AppStorage.getInstance();
      if (!mounted || storage.getString('catalog_refresh_on_resume') != 'true') return;
      if (!widget.catalogRepo.isLoading) await widget.catalogRepo.loadCatalog();
    } finally {
      _refreshingOnResume = false;
    }
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
    WidgetsBinding.instance.removeObserver(this);
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
    final isSeries = items.first.isSeries;
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final compact = MediaQuery.sizeOf(context).height < 450;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 10, 10),
        child: Row(children: [
          Expanded(child: Text(title, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          TextButton(
            onPressed: () => setState(() => _currentNavIndex = isSeries ? 3 : 2),
            child: const Text('Ver tudo ›',
              style: TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
      ),
      SizedBox(height: (compact ? 175 : 205) + 45 * scale,
        child: ListView.separated(
          key: PageStorageKey('home-rail-$title'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: items.length > 12 ? 12 : items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (_, index) {
            final item = items[index];
            return SizedBox(width: compact ? 114 : 132,
              child: MediaPosterCard(media: item,
                onTap: () => _openMedia(item, playlist: items)));
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
          SliverToBoxAdapter(child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = MediaQuery.sizeOf(context).height < 460;
              return SizedBox(height: compact ? 220 : 390,
                child: Stack(fit: StackFit.expand, children: [
                  CatalogArtwork(url: featured.backdropUrl ?? featured.posterUrl),
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0x1108080B), Color(0xDD08080B), Color(0xFF121212)],
                      stops: [0.12, 0.72, 1]))),
                  Positioned(left: 20, right: 20, bottom: 22,
                    child: Column(mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(featured.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 29,
                            height: 1.1, fontWeight: FontWeight.w900)),
                        if (featured.categoryName != null) ...[
                          const SizedBox(height: 6),
                          Text(featured.categoryName!, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70)),
                        ],
                        if (!compact && (featured.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 9),
                          Text(featured.description!, maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, height: 1.3)),
                        ],
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _openMedia(featured,
                            playlist: featured.isSeries ? series : movies),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Assistir')),
                      ])),
                ]));
            },
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
        if (featured != null || widget.catalogRepo.isLoading)
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
      if (channels.isNotEmpty || widget.catalogRepo.isLoading)
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
    ]);
  }

  Widget _mediaTab(List<MediaItem> items, {required bool series}) {
    final query = series ? _seriesQuery : _movieQuery;
    final selectedCategory = series ? _seriesCategory : _movieCategory;
    // Xtream identifies streams by category_id; category_name is often absent.
    // Use provider definitions, falling back to M3U item categories.
    final definitions = series ? widget.catalogRepo.seriesCategories
        : widget.catalogRepo.vodCategories;
    final categoryLabels = <String, String>{};
    for (final category in definitions) {
      final id = category['category_id']?.toString().trim() ?? '';
      final label = category['category_name']?.toString().trim() ?? '';
      if (id.isNotEmpty) categoryLabels[id] = label.isNotEmpty ? label : id;
    }
    for (final item in items) {
      final id = item.categoryId?.trim() ?? '';
      final name = item.categoryName?.trim() ?? '';
      if (id.isNotEmpty) {
        categoryLabels.putIfAbsent(id, () => name.isNotEmpty ? name : id);
      } else if (name.isNotEmpty) {
        categoryLabels.putIfAbsent(name, () => name);
      }
    }
    final categories = categoryLabels.keys.toList()
      ..sort((a, b) => categoryLabels[a]!.toLowerCase()
          .compareTo(categoryLabels[b]!.toLowerCase()));
    final activeCategory = categories.contains(selectedCategory) ? selectedCategory : null;
    final visible = items.where((item) {
      final id = item.categoryId?.trim();
      final name = item.categoryName?.trim();
      return item.title.toLowerCase().contains(query.toLowerCase()) &&
          (activeCategory == null || id == activeCategory ||
            (id == null || id.isEmpty) && name == activeCategory);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (MediaQuery.sizeOf(context).height < 450)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(series ? 'Séries' : 'Filmes',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        )
      else
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
      if (categories.isNotEmpty)
        SizedBox(height: 64, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          children: [
            Padding(padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: const Text('Todos'),
                selected: activeCategory == null,
                onSelected: (_) => setState(() {
                  if (series) { _seriesCategory = null; }
                  else { _movieCategory = null; }
                }))),
            for (final category in categories)
              Padding(padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categoryLabels[category] ?? category),
                  selected: activeCategory == category,
                  onSelected: (_) => setState(() {
                    if (series) { _seriesCategory = category; }
                    else { _movieCategory = category; }
                  }))),
          ],
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
      if (channels.isNotEmpty)
        SliverList(delegate: SliverChildBuilderDelegate((_, index) =>
          _channelTile(channels[index], channels, favorite: true), childCount: channels.length)),
      if (media.isNotEmpty)
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
        title: const Text.rich(TextSpan(children: [
          TextSpan(text: 'BEST', style: TextStyle(color: Colors.redAccent)),
          TextSpan(text: ' PLAYER', style: TextStyle(color: Colors.white)),
        ]), style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SettingsScreen(
                authRepo: widget.authRepo,
                catalogRepo: widget.catalogRepo,
                libraryRepo: _libraryRepo!))),

          ),
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
