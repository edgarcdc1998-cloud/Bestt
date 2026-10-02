import '../models/channel.dart';
import '../models/episode.dart';
import '../models/media_item.dart';
import '../models/playback_type.dart';
import '../models/xtream_config.dart';
import 'http_client.dart';

class XtreamService {
  final HttpClient _httpClient;

  XtreamService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  Future<Map<String, dynamic>> authenticate(XtreamConfig config) async {
    final uri = Uri.parse(config.playerApiUrl);
    final data = await _httpClient.getJson(uri);
    if (data is Map<String, dynamic>) {
      final userInfo = data['user_info'];
      if (userInfo != null && userInfo['auth'] == 1 && userInfo['status'] == 'Active') {
        return data;
      }
      throw Exception('Autenticação inválida ou conta inativa');
    }
    throw Exception('Resposta inesperada do servidor Xtream');
  }

  Future<List<Map<String, dynamic>>> getLiveCategories(XtreamConfig config) async {
    final uri = Uri.parse(config.liveCategoriesUrl);
    final data = await _httpClient.getJson(uri);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.whereType<Map>());
    }
    return [];
  }

  Future<List<Channel>> getLiveStreams(XtreamConfig config, {String? categoryId}) async {
    String url = config.liveStreamsUrl;
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _httpClient.getJson(Uri.parse(url));
    if (data is List) {
      return data.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final streamId = int.tryParse(map['stream_id']?.toString() ?? '') ?? 0;
        return Channel(
          id: 'xtream_live_$streamId',
          name: map['name'] as String? ?? 'Canal $streamId',
          streamUrl: config.liveStreamUrl(streamId),
          logoUrl: map['stream_icon'] as String?,
          categoryId: map['category_id']?.toString(),
          categoryName: map['category_name'] as String?,
          tvgId: map['epg_channel_id'] as String?,
          streamId: streamId,
        );
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getVodCategories(XtreamConfig config) async {
    final uri = Uri.parse(config.vodCategoriesUrl);
    final data = await _httpClient.getJson(uri);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.whereType<Map>());
    }
    return [];
  }

  Future<List<MediaItem>> getVodStreams(XtreamConfig config, {String? categoryId}) async {
    String url = config.vodStreamsUrl;
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _httpClient.getJson(Uri.parse(url));
    if (data is List) {
      return data.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final streamId = int.tryParse(map['stream_id']?.toString() ?? '') ?? 0;
        final extension = map['container_extension'] as String? ?? 'mp4';
        return MediaItem(
          id: 'xtream_vod_$streamId',
          title: map['name'] as String? ?? 'Filme $streamId',
          streamUrl: config.movieStreamUrl(streamId, extension: extension),
          type: PlaybackType.movie,
          posterUrl: map['stream_icon'] as String?,
          categoryId: map['category_id']?.toString(),
          categoryName: map['category_name'] as String?,
          streamId: streamId,
          containerExtension: extension,
        );
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getSeriesCategories(XtreamConfig config) async {
    final uri = Uri.parse(config.seriesCategoriesUrl);
    final data = await _httpClient.getJson(uri);
    if (data is List) {
      return List<Map<String, dynamic>>.from(data.whereType<Map>());
    }
    return [];
  }

  Future<List<MediaItem>> getSeries(XtreamConfig config, {String? categoryId}) async {
    String url = config.seriesUrl;
    if (categoryId != null && categoryId.isNotEmpty) {
      url += '&category_id=$categoryId';
    }
    final data = await _httpClient.getJson(Uri.parse(url));
    if (data is List) {
      return data.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final seriesId = int.tryParse(map['series_id']?.toString() ?? '') ?? 0;
        return MediaItem(
          id: 'xtream_series_$seriesId',
          title: map['name'] as String? ?? 'Série $seriesId',
          streamUrl: '', // Series contain episodes
          type: PlaybackType.series,
          posterUrl: map['cover'] as String?,
          backdropUrl: (map['backdrop_path'] is List && (map['backdrop_path'] as List).isNotEmpty)
              ? (map['backdrop_path'] as List).first.toString()
              : null,
          categoryId: map['category_id']?.toString(),
          categoryName: map['category_name'] as String?,
          description: map['plot'] as String?,
          seriesId: seriesId.toString(),
        );
      }).toList();
    }
    return [];
  }

  Future<Map<String, List<Episode>>> getSeriesInfo(XtreamConfig config, int seriesId) async {
    final uri = Uri.parse(config.seriesInfoUrl(seriesId));
    final data = await _httpClient.getJson(uri);
    final Map<String, List<Episode>> seasonsMap = {};

    if (data is Map && data['episodes'] is Map) {
      final episodesData = data['episodes'] as Map;
      episodesData.forEach((seasonKey, episodesList) {
        if (episodesList is List) {
          final List<Episode> parsedEpisodes = [];
          for (final epItem in episodesList) {
            if (epItem is Map) {
              final epMap = Map<String, dynamic>.from(epItem);
              final epId = epMap['id']?.toString() ?? '';
              final epNum = int.tryParse(epMap['episode_num']?.toString() ?? '1') ?? 1;
              final seasonNum = int.tryParse(epMap['season']?.toString() ?? seasonKey.toString()) ?? 1;
              final ext = epMap['container_extension'] as String? ?? 'mp4';
              final streamUrl = config.seriesStreamUrl(int.tryParse(epId) ?? 0, extension: ext);

              parsedEpisodes.add(
                Episode(
                  id: epId,
                  seriesId: seriesId.toString(),
                  seasonNumber: seasonNum,
                  episodeNumber: epNum,
                  title: epMap['title'] as String? ?? 'Episódio $epNum',
                  streamUrl: streamUrl,
                  coverUrl: epMap['info']?['movie_image'] as String?,
                  plot: epMap['info']?['plot'] as String?,
                  duration: epMap['info']?['duration'] as String?,
                  containerExtension: ext,
                ),
              );
            }
          }
          seasonsMap[seasonKey.toString()] = parsedEpisodes;
        }
      });
    }
    return seasonsMap;
  }
}
