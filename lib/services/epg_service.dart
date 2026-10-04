import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/epg_program.dart';
import '../models/xtream_config.dart';
import 'http_client.dart';

class EpgService {
  final HttpClient _httpClient;
  final Map<String, List<EpgProgram>> _epgCache = {};

  EpgService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  /// Parses XMLTV dates in format "YYYYMMDDHHmmss [+/-HHMM]" or ISO8601
  static DateTime? parseXmlTvDate(String dateStr) {
    final trimmed = dateStr.trim();
    if (trimmed.isEmpty) return null;

    try {
      if (trimmed.length >= 14 && RegExp(r'^\d{14}').hasMatch(trimmed)) {
        final year = int.parse(trimmed.substring(0, 4));
        final month = int.parse(trimmed.substring(4, 6));
        final day = int.parse(trimmed.substring(6, 8));
        final hour = int.parse(trimmed.substring(8, 10));
        final minute = int.parse(trimmed.substring(10, 12));
        final second = int.parse(trimmed.substring(12, 14));

        var dt = DateTime.utc(year, month, day, hour, minute, second);
        final tzMatch = RegExp(r'([+-])(\d{2})(\d{2})$').firstMatch(trimmed);
        if (tzMatch != null) {
          final sign = tzMatch.group(1) == '-' ? -1 : 1;
          final tzHour = int.parse(tzMatch.group(2)!);
          final tzMin = int.parse(tzMatch.group(3)!);
          final offsetDuration = Duration(hours: tzHour, minutes: tzMin) * sign;
          dt = dt.subtract(offsetDuration);
        }
        return dt.toLocal();
      }
      return DateTime.tryParse(trimmed)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Parses XMLTV format XML string into indexed EPG programs by channel ID
  Map<String, List<EpgProgram>> parseXmlTv(String xmlContent) {
    final Map<String, List<EpgProgram>> result = {};
    if (xmlContent.isEmpty) return result;

    // Fast regex extraction of <programme> elements
    final progRegex = RegExp(
      r'<programme\s+([^>]*?)>(.*?)</programme>',
      caseSensitive: false,
      dotAll: true,
    );
    final attrRegex = RegExp(r'''([\w\-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''', caseSensitive: false);
    final titleRegex = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);
    final descRegex = RegExp(r'<desc[^>]*>(.*?)</desc>', caseSensitive: false, dotAll: true);

    int count = 0;
    for (final progMatch in progRegex.allMatches(xmlContent)) {
      final attrsStr = progMatch.group(1) ?? '';
      final bodyStr = progMatch.group(2) ?? '';

      String? startStr;
      String? stopStr;
      String? channelId;

      for (final attrMatch in attrRegex.allMatches(attrsStr)) {
        final key = attrMatch.group(1)?.toLowerCase();
        final val = attrMatch.group(2) ?? attrMatch.group(3);
        if (key == 'start') startStr = val;
        if (key == 'stop') stopStr = val;
        if (key == 'channel') channelId = val;
      }

      if (channelId == null || startStr == null || stopStr == null) continue;

      final start = parseXmlTvDate(startStr);
      final stop = parseXmlTvDate(stopStr);
      if (start == null || stop == null) continue;

      final titleMatch = titleRegex.firstMatch(bodyStr);
      final title = titleMatch != null ? _cleanXml(titleMatch.group(1) ?? '') : 'Sem Título';

      final descMatch = descRegex.firstMatch(bodyStr);
      final desc = descMatch != null ? _cleanXml(descMatch.group(1) ?? '') : null;

      final program = EpgProgram(
        id: 'xmltv_${++count}',
        channelId: channelId,
        title: title.isNotEmpty ? title : 'Sem Título',
        description: desc,
        startTime: start,
        endTime: stop,
      );

      result.putIfAbsent(channelId, () => []).add(program);

      final lowerChannelId = channelId.toLowerCase();
      if (lowerChannelId != channelId) {
        result.putIfAbsent(lowerChannelId, () => []).add(program);
      }
    }

    // Sort programs by startTime
    for (final list in result.values) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));
    }

    _epgCache.addAll(result);
    return result;
  }

  static String _cleanXml(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  /// Downloads and parses XMLTV file (handles both plain XML and GZIP .xml.gz)
  Future<Map<String, List<EpgProgram>>> fetchXmlTv(String url) async {
    try {
      final uri = Uri.parse(url);
      final streamResponse = await _httpClient.getStream(uri);
      if (streamResponse.statusCode >= 200 && streamResponse.statusCode < 300) {
        final bytes = await streamResponse.stream.toBytes();
        String xml;

        // Check if GZIP by magic bytes 0x1F, 0x8B
        if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
          final decompressed = GZipCodec().decode(bytes);
          xml = utf8.decode(decompressed, allowMalformed: true);
        } else {
          xml = utf8.decode(bytes, allowMalformed: true);
        }

        return parseXmlTv(xml);
      }
    } catch (e) {
      debugPrint('[EpgService] Error fetching XMLTV: $e');
    }
    return {};
  }

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

  List<EpgProgram> getProgramsForChannel(String? channelId) {
    if (channelId == null || channelId.isEmpty) return [];
    return _epgCache[channelId] ?? _epgCache[channelId.toLowerCase()] ?? [];
  }

  EpgProgram? getCurrentProgram(String? channelId) {
    if (channelId == null || channelId.isEmpty) return null;
    final list = _epgCache[channelId] ?? _epgCache[channelId.toLowerCase()];
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    for (final prog in list) {
      if (now.isAfter(prog.startTime) && now.isBefore(prog.endTime)) {
        return prog;
      }
    }
    return null;
  }

  EpgProgram? getNextProgram(String? channelId) {
    if (channelId == null || channelId.isEmpty) return null;
    final list = _epgCache[channelId] ?? _epgCache[channelId.toLowerCase()];
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
