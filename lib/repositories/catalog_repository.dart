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

  List<Map<String, dynamic>> _liveCategories = [];
  List<Map<String, dynamic>> _vodCategories = [];
  List<Map<String, dynamic>> _seriesCategories = [];

  List<Channel> _channels = [];
  List<MediaItem> _movies = [];
  List<MediaItem> _series = [];

  bool _isLoading = false;

  CatalogRepository(
    this._authRepo, {
    XtreamService? xtreamService,
    PlaylistService? playlistService,
  })  : _xtreamService = xtreamService ?? XtreamService(),
        _playlistService = playlistService ?? PlaylistService();

  List<Map<String, dynamic>> get liveCategories => _liveCategories;
  List<Map<String, dynamic>> get vodCategories => _vodCategories;
  List<Map<String, dynamic>> get seriesCategories => _seriesCategories;

  List<Channel> get channels => _channels;
  List<MediaItem> get movies => _movies;
  List<MediaItem> get series => _series;
  bool get isLoading => _isLoading;

  Future<void> loadCatalog() async {
    if (!_authRepo.isAuthenticated) return;
    _isLoading = true;
    notifyListeners();

    try {
      if (_authRepo.authType == AuthType.xtream && _authRepo.xtreamConfig != null) {
        final config = _authRepo.xtreamConfig!;
        _liveCategories = await _xtreamService.getLiveCategories(config);
        _vodCategories = await _xtreamService.getVodCategories(config);
        _seriesCategories = await _xtreamService.getSeriesCategories(config);

        _channels = await _xtreamService.getLiveStreams(config);
        _movies = await _xtreamService.getVodStreams(config);
        _series = await _xtreamService.getSeries(config);
      } else if (_authRepo.authType == AuthType.m3u && _authRepo.m3uUrl != null) {
        _channels = await _playlistService.fetchPlaylist(_authRepo.m3uUrl!);
        // Extract distinct categories from M3U
        final categoriesSet = <String>{};
        for (final ch in _channels) {
          if (ch.categoryName != null) {
            categoriesSet.add(ch.categoryName!);
          }
        }
        _liveCategories = categoriesSet
            .map((cat) => {'category_id': cat, 'category_name': cat})
            .toList();
        _vodCategories = [];
        _seriesCategories = [];
        _movies = [];
        _series = [];
      }
    } catch (e) {
      debugPrint('[CatalogRepository] Error loading catalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Channel>> getChannelsByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _channels;
    return _channels.where((c) => c.categoryId == categoryId || c.categoryName == categoryId).toList();
  }

  Future<List<MediaItem>> getMoviesByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _movies;
    return _movies.where((m) => m.categoryId == categoryId).toList();
  }

  Future<List<MediaItem>> getSeriesByCategory(String? categoryId) async {
    if (categoryId == null || categoryId == 'all') return _series;
    return _series.where((s) => s.categoryId == categoryId).toList();
  }
}
