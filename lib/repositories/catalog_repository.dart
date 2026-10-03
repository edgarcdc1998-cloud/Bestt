import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/media_item.dart';
import '../models/xtream_config.dart';
import '../services/playlist_service.dart';
import '../services/xtream_service.dart';
import 'authentication_repository.dart';

class CatalogRepository extends ChangeNotifier {
  final AuthenticationRepository _authRepo;
  final XtreamService _xtreamService;
  final PlaylistService _playlistService;

  int _catalogGeneration = 0;

  List<Map<String, dynamic>> _liveCategories = [];
  List<Map<String, dynamic>> _vodCategories = [];
  List<Map<String, dynamic>> _seriesCategories = [];

  List<Channel> _channels = [];
  List<MediaItem> _movies = [];
  List<MediaItem> _series = [];

  // Indexed categories for fast O(1) lookup (ETAPA 4B)
  final Map<String, List<Channel>> _channelsByCategory = {};
  final Map<String, List<MediaItem>> _moviesByCategory = {};
  final Map<String, List<MediaItem>> _seriesByCategory = {};

  bool _isLoading = false;

  CatalogRepository(
    this._authRepo, {
    XtreamService? xtreamService,
    PlaylistService? playlistService,
  })  : _xtreamService = xtreamService ?? XtreamService(),
        _playlistService = playlistService ?? PlaylistService();

  int get catalogGeneration => _catalogGeneration;
  List<Map<String, dynamic>> get liveCategories => _liveCategories;
  List<Map<String, dynamic>> get vodCategories => _vodCategories;
  List<Map<String, dynamic>> get seriesCategories => _seriesCategories;

  List<Channel> get channels => _channels;
  List<MediaItem> get movies => _movies;
  List<MediaItem> get series => _series;
  bool get isLoading => _isLoading;

  Future<void> loadCatalog() async {
    if (!_authRepo.isAuthenticated) return;

    // Invalidate any previous catalog loading generations (ETAPA 5)
    final generation = ++_catalogGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      if (_authRepo.authType == AuthType.xtream && _authRepo.xtreamConfig != null) {
        final config = _authRepo.xtreamConfig!;
        final liveCats = await _xtreamService.getLiveCategories(config);
        if (generation != _catalogGeneration) return;

        final vodCats = await _xtreamService.getVodCategories(config);
        if (generation != _catalogGeneration) return;

        final seriesCats = await _xtreamService.getSeriesCategories(config);
        if (generation != _catalogGeneration) return;

        final liveStreams = await _xtreamService.getLiveStreams(config);
        if (generation != _catalogGeneration) return;

        final vodStreams = await _xtreamService.getVodStreams(config);
        if (generation != _catalogGeneration) return;

        final seriesStreams = await _xtreamService.getSeries(config);
        if (generation != _catalogGeneration) return;

        // Build local index maps atomically
        final localChannelsByCategory = <String, List<Channel>>{};
        for (final ch in liveStreams) {
          final catId = ch.categoryId ?? 'all';
          localChannelsByCategory.putIfAbsent(catId, () => []).add(ch);
        }

        final localMoviesByCategory = <String, List<MediaItem>>{};
        for (final m in vodStreams) {
          final catId = m.categoryId ?? 'all';
          localMoviesByCategory.putIfAbsent(catId, () => []).add(m);
        }

        final localSeriesByCategory = <String, List<MediaItem>>{};
        for (final s in seriesStreams) {
          final catId = s.categoryId ?? 'all';
          localSeriesByCategory.putIfAbsent(catId, () => []).add(s);
        }

        if (generation != _catalogGeneration) return;

        // Commit state atomically
        _liveCategories = liveCats;
        _vodCategories = vodCats;
        _seriesCategories = seriesCats;
        _channels = liveStreams;
        _movies = vodStreams;
        _series = seriesStreams;

        _channelsByCategory.clear();
        _channelsByCategory.addAll(localChannelsByCategory);
        _moviesByCategory.clear();
        _moviesByCategory.addAll(localMoviesByCategory);
        _seriesByCategory.clear();
        _seriesByCategory.addAll(localSeriesByCategory);
      } else if (_authRepo.authType == AuthType.m3u && _authRepo.m3uUrl != null) {
        final fetchedChannels = await _playlistService.fetchPlaylist(_authRepo.m3uUrl!);
        if (generation != _catalogGeneration) return;

        // Build local structures atomically
        final localChannelsByCategory = <String, List<Channel>>{};
        final orderedCategories = <String>[];
        final categoriesSet = <String>{};

        for (final ch in fetchedChannels) {
          final cat = ch.categoryName ?? 'Geral';
          if (categoriesSet.add(cat)) {
            orderedCategories.add(cat);
          }
          final catId = ch.categoryId ?? cat;
          localChannelsByCategory.putIfAbsent(catId, () => []).add(ch);
          if (ch.categoryName != null && ch.categoryName != catId) {
            localChannelsByCategory.putIfAbsent(ch.categoryName!, () => []).add(ch);
          }
        }

        final localLiveCategories = orderedCategories
            .map((cat) => {'category_id': cat, 'category_name': cat})
            .toList();

        if (generation != _catalogGeneration) return;

        // Commit state atomically
        _channels = fetchedChannels;
        _channelsByCategory.clear();
        _channelsByCategory.addAll(localChannelsByCategory);
        _liveCategories = localLiveCategories;

        _vodCategories = [];
        _seriesCategories = [];
        _movies = [];
        _series = [];
        _moviesByCategory.clear();
        _seriesByCategory.clear();
      }
    } catch (e) {
      if (generation == _catalogGeneration) {
        debugPrint('[CatalogRepository] Error loading catalog: $e');
      }
    } finally {
      if (generation == _catalogGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<Channel>> getChannelsByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _channels;
    if (_channelsByCategory.containsKey(categoryId)) {
      return _channelsByCategory[categoryId]!;
    }
    return _channels.where((c) => c.categoryId == categoryId || c.categoryName == categoryId).toList();
  }

  Future<List<MediaItem>> getMoviesByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _movies;
    if (_moviesByCategory.containsKey(categoryId)) {
      return _moviesByCategory[categoryId]!;
    }
    return _movies.where((m) => m.categoryId == categoryId).toList();
  }

  Future<List<MediaItem>> getSeriesByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _series;
    if (_seriesByCategory.containsKey(categoryId)) {
      return _seriesByCategory[categoryId]!;
    }
    return _series.where((s) => s.categoryId == categoryId).toList();
  }
}
