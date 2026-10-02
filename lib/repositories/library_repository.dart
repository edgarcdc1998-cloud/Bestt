import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/media_item.dart';
import '../services/app_storage.dart';

class LibraryRepository extends ChangeNotifier {
  final AppStorage _storage;

  List<Channel> _favoriteChannels = [];
  List<MediaItem> _favoriteMedia = [];
  List<MediaItem> _watchHistory = [];
  final Map<String, Duration> _resumePositions = {};

  LibraryRepository(this._storage);

  List<Channel> get favoriteChannels => _favoriteChannels;
  List<MediaItem> get favoriteMedia => _favoriteMedia;
  List<MediaItem> get watchHistory => _watchHistory;
  Map<String, Duration> get resumePositions => _resumePositions;

  static const String _keyFavChannels = 'fav_channels';
  static const String _keyFavMedia = 'fav_media';
  static const String _keyWatchHistory = 'watch_history';
  static const String _keyResumePositions = 'resume_positions';

  Future<void> init() async {
    try {
      // P0-3: Defensive loading with per-item resilience
      _favoriteChannels = _storage.getModelList<Channel>(
        _keyFavChannels,
        (json) => Channel.fromJson(json),
      );

      _favoriteMedia = _storage.getModelList<MediaItem>(
        _keyFavMedia,
        (json) => MediaItem.fromJson(json),
      );

      _watchHistory = _storage.getModelList<MediaItem>(
        _keyWatchHistory,
        (json) => MediaItem.fromJson(json),
      );

      final rawResume = _storage.getJsonMap(_keyResumePositions, defaultValue: {});
      _resumePositions.clear();
      if (rawResume != null) {
        rawResume.forEach((key, value) {
          if (value is int) {
            _resumePositions[key] = Duration(milliseconds: value);
          } else if (value != null) {
            final parsed = int.tryParse(value.toString());
            if (parsed != null) {
              _resumePositions[key] = Duration(milliseconds: parsed);
            }
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[LibraryRepository] Controlled recovery from corrupted storage during init: $e\n$stack');
      // Graceful fallback to empty state without throwing
    }
    notifyListeners();
  }

  bool isChannelFavorite(String channelId) {
    return _favoriteChannels.any((c) => c.id == channelId);
  }

  Future<void> toggleChannelFavorite(Channel channel) async {
    final index = _favoriteChannels.indexWhere((c) => c.id == channel.id);
    if (index >= 0) {
      _favoriteChannels.removeAt(index);
    } else {
      _favoriteChannels.add(channel);
    }
    notifyListeners();
    await _storage.setJson(_keyFavChannels, _favoriteChannels.map((c) => c.toJson()).toList());
  }

  bool isMediaFavorite(String mediaId) {
    return _favoriteMedia.any((m) => m.id == mediaId);
  }

  Future<void> toggleMediaFavorite(MediaItem media) async {
    final index = _favoriteMedia.indexWhere((m) => m.id == media.id);
    if (index >= 0) {
      _favoriteMedia.removeAt(index);
    } else {
      _favoriteMedia.add(media);
    }
    notifyListeners();
    await _storage.setJson(_keyFavMedia, _favoriteMedia.map((m) => m.toJson()).toList());
  }

  Future<void> addToHistory(MediaItem media) async {
    _watchHistory.removeWhere((m) => m.id == media.id);
    _watchHistory.insert(0, media);
    if (_watchHistory.length > 50) {
      _watchHistory = _watchHistory.sublist(0, 50);
    }
    notifyListeners();
    await _storage.setJson(_keyWatchHistory, _watchHistory.map((m) => m.toJson()).toList());
  }

  Duration? getResumePosition(String mediaId) {
    return _resumePositions[mediaId];
  }

  Future<void> saveResumePosition(String mediaId, Duration position) async {
    if (position.inSeconds < 5) return;
    _resumePositions[mediaId] = position;
    final mapToSave = _resumePositions.map((k, v) => MapEntry(k, v.inMilliseconds));
    await _storage.setJson(_keyResumePositions, mapToSave);
  }

  Future<void> clearHistory() async {
    _watchHistory.clear();
    notifyListeners();
    await _storage.remove(_keyWatchHistory);
  }
}
