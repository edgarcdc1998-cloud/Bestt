import '../models/epg_program.dart';
import '../models/xtream_config.dart';
import 'http_client.dart';

class EpgService {
  final HttpClient _httpClient;
  final Map<String, List<EpgProgram>> _epgCache = {};

  EpgService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  Future<List<EpgProgram>> getShortEpg(XtreamConfig config, int streamId) async {
    final cacheKey = streamId.toString();
    if (_epgCache.containsKey(cacheKey) && _epgCache[cacheKey]!.isNotEmpty) {
      return _epgCache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(config.shortEpgUrl(streamId));
      final data = await _httpClient.getJson(uri);
      if (data is Map && data['epg_listings'] is List) {
        final listings = data['epg_listings'] as List;
        final programs = listings.whereType<Map>().map((item) {
          final map = Map<String, dynamic>.from(item);
          return EpgProgram(
            id: map['id']?.toString() ?? '',
            channelId: streamId.toString(),
            title: map['title'] as String? ?? 'Sem Título',
            description: map['descr'] as String? ?? map['description'] as String?,
            startTime: DateTime.tryParse(map['start'] as String? ?? '') ?? DateTime.now(),
            endTime: DateTime.tryParse(map['end'] as String? ?? '') ?? DateTime.now(),
          );
        }).toList();

        _epgCache[cacheKey] = programs;
        return programs;
      }
    } catch (_) {
      // Return cached or empty on error
    }
    return _epgCache[cacheKey] ?? [];
  }

  EpgProgram? getCurrentProgram(String channelId) {
    final list = _epgCache[channelId];
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    for (final prog in list) {
      if (now.isAfter(prog.startTime) && now.isBefore(prog.endTime)) {
        return prog;
      }
    }
    return null;
  }

  EpgProgram? getNextProgram(String channelId) {
    final list = _epgCache[channelId];
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    for (final prog in list) {
      if (prog.startTime.isAfter(now)) {
        return prog;
      }
    }
    return null;
  }

  void clearCache() {
    _epgCache.clear();
  }
}
