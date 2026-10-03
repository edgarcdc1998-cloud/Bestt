import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../repositories/authentication_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/library_repository.dart';
import '../services/app_storage.dart';
import 'epg_screen.dart';
import 'login_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthenticationRepository authRepo;
  final CatalogRepository catalogRepo;

  const HomeScreen({
    super.key,
    required this.authRepo,
    required this.catalogRepo,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  String? _selectedCategory;
  late LibraryRepository _libraryRepo;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initLibrary();
  }

  Future<void> _initLibrary() async {
    final storage = await AppStorage.getInstance();
    _libraryRepo = LibraryRepository(storage);
    await _libraryRepo.init();
    if (mounted) {
      setState(() {
        _isInit = true;
      });
    }
  }

  void _playMedia(MediaItem media, {List<MediaItem>? playlist}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media,
          playlist: playlist,
          libraryRepository: _libraryRepo,
        ),
      ),
    );
  }

  void _playChannel(Channel channel, {List<Channel>? channelList}) {
    final media = MediaItem(
      id: channel.id,
      title: channel.name,
      streamUrl: channel.streamUrl,
      type: PlaybackType.live,
      posterUrl: channel.logoUrl,
      categoryId: channel.categoryId,
      categoryName: channel.categoryName,
      streamId: channel.streamId,
    );

    List<MediaItem>? playlist;
    if (channelList != null && channelList.isNotEmpty) {
      playlist = channelList.map((ch) => MediaItem(
        id: ch.id,
        title: ch.name,
        streamUrl: ch.streamUrl,
        type: PlaybackType.live,
        posterUrl: ch.logoUrl,
        categoryId: ch.categoryId,
        categoryName: ch.categoryName,
        streamId: ch.streamId,
      )).toList();
    }

    _playMedia(media, playlist: playlist);
  }

  Widget _buildLiveTab() {
    return FutureBuilder<List<Channel>>(
      future: widget.catalogRepo.getChannelsByCategory(_selectedCategory),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }
        final channels = snapshot.data!;
        if (channels.isEmpty) {
          return const Center(child: Text('Nenhum canal encontrado', style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final ch = channels[index];
            final isFav = _libraryRepo.isChannelFavorite(ch.id);

            return ListTile(
              leading: ch.logoUrl != null
                  ? Image.network(
                      ch.logoUrl!,
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white54, size: 36),
                    )
                  : const Icon(Icons.tv, color: Colors.white54, size: 36),
              title: Text(ch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: ch.categoryName != null
                  ? Text(ch.categoryName!, style: const TextStyle(color: Colors.white54, fontSize: 12))
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.white54),
                    onPressed: () {
                      _libraryRepo.toggleChannelFavorite(ch);
                      setState(() {});
                    },
                  ),
                  const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 32),
                ],
              ),
              onTap: () => _playChannel(ch, channelList: channels),
            );
          },
        );
      },
    );
  }

  Widget _buildMoviesTab() {
    return FutureBuilder<List<MediaItem>>(
      future: widget.catalogRepo.getMoviesByCategory(_selectedCategory),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }
        final movies = snapshot.data!;
        if (movies.isEmpty) {
          return const Center(child: Text('Nenhum filme encontrado', style: TextStyle(color: Colors.white54)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return GestureDetector(
              onTap: () => _playMedia(movie, playlist: movies),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: movie.posterUrl != null
                            ? Image.network(
                                movie.posterUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.movie, color: Colors.white30, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.movie, color: Colors.white30, size: 48),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          movie.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeriesTab() {
    return FutureBuilder<List<MediaItem>>(
      future: widget.catalogRepo.getSeriesByCategory(_selectedCategory),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }
        final seriesList = snapshot.data!;
        if (seriesList.isEmpty) {
          return const Center(child: Text('Nenhuma série encontrada', style: TextStyle(color: Colors.white54)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: seriesList.length,
          itemBuilder: (context, index) {
            final series = seriesList[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeriesDetailScreen(
                      series: series,
                      authRepo: widget.authRepo,
                      libraryRepo: _libraryRepo,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: series.posterUrl != null
                            ? Image.network(
                                series.posterUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.tv_outlined, color: Colors.white30, size: 48),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.tv_outlined, color: Colors.white30, size: 48),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          series.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    final favChannels = _libraryRepo.favoriteChannels;
    final favMedia = _libraryRepo.favoriteMedia;

    if (favChannels.isEmpty && favMedia.isEmpty) {
      return const Center(
        child: Text('Nenhum favorito adicionado ainda', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView(
      children: [
        if (favChannels.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('CANAIS FAVORITOS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ...favChannels.map((ch) => ListTile(
                leading: const Icon(Icons.tv, color: Colors.white54),
                title: Text(ch.name, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.play_arrow, color: Colors.redAccent),
                onTap: () => _playChannel(ch),
              )),
        ],
        if (favMedia.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('FILMES E SÉRIES FAVORITOS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ...favMedia.map((m) => ListTile(
                leading: const Icon(Icons.movie, color: Colors.white54),
                title: Text(m.title, style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.play_arrow, color: Colors.redAccent),
                onTap: () => _playMedia(m),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('BEST PLAYER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_timeline_outlined),
            tooltip: 'EPG',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EpgScreen(
                    channels: widget.catalogRepo.channels,
                    authRepo: widget.authRepo,
                    libraryRepo: _libraryRepo,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await widget.authRepo.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      authRepo: widget.authRepo,
                      catalogRepo: widget.catalogRepo,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildLiveTab(),
          _buildMoviesTab(),
          _buildSeriesTab(),
          _buildFavoritesTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
            _selectedCategory = null;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Ao Vivo'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Filmes'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Séries'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favoritos'),
        ],
      ),
    );
  }
}
