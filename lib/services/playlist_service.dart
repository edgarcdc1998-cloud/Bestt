import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import 'http_client.dart';
import 'm3u_parser.dart';

class PlaylistService {
  final HttpClient _httpClient;

  PlaylistService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  static String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery && uri.userInfo.isEmpty) {
        return url;
      }
      final sanitizedParams = Map<String, String>.from(uri.queryParameters);
      for (final key in sanitizedParams.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('pass') ||
            lower.contains('token') ||
            lower.contains('user') ||
            lower.contains('auth') ||
            lower.contains('key') ||
            lower.contains('secret')) {
          sanitizedParams[key] = '***';
        }
      }
      return uri.replace(
        userInfo: uri.userInfo.isNotEmpty ? '***:***' : null,
        queryParameters: sanitizedParams.isNotEmpty ? sanitizedParams : null,
      ).toString();
    } catch (_) {
      return 'url_redacted';
    }
  }

  /// Fetches an M3U playlist via HTTP streaming, decoding lines incrementally without loading full body string (ETAPA 4D).
  /// Instrumented with detailed diagnostics to measure connection, download, decoding and parsing stages.
  Future<List<Channel>> fetchPlaylist(String url) async {
    final totalStopwatch = Stopwatch()..start();
    final sanitizedUrl = _sanitizeUrl(url);
    debugPrint('[PLAYLIST_DIAGNOSTIC] download started url=$sanitizedUrl');

    final uri = Uri.parse(url);
    final http.StreamedResponse response;
    try {
      final headerStopwatch = Stopwatch()..start();
      response = await _httpClient.getStream(uri);
      headerStopwatch.stop();

      final contentType = response.headers['content-type'] ?? 'unknown';
      final contentLength = response.contentLength?.toString() ?? response.headers['content-length'] ?? 'chunked/unknown';
      debugPrint('[PLAYLIST_DIAGNOSTIC] headers received elapsedMs=${headerStopwatch.elapsedMilliseconds} status=${response.statusCode} contentType=$contentType contentLength=$contentLength');
    } catch (e) {
      debugPrint('[PLAYLIST_DIAGNOSTIC] error stage=http_request type=${e.runtimeType} message=$e');
      rethrow;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      int byteCount = 0;
      int lineCount = 0;
      final lines = <String>[];
      final streamStopwatch = Stopwatch()..start();

      try {
        await for (final line in response.stream
            .map((chunk) {
              byteCount += chunk.length;
              return chunk;
            })
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          lineCount++;
          lines.add(line);
        }
        streamStopwatch.stop();
        debugPrint('[PLAYLIST_DIAGNOSTIC] download completed elapsedMs=${streamStopwatch.elapsedMilliseconds} bytes=$byteCount lines=$lineCount');
      } catch (e) {
        debugPrint('[PLAYLIST_DIAGNOSTIC] error stage=stream_decoding type=${e.runtimeType} message=$e bytesReceived=$byteCount linesReceived=$lineCount');
        rethrow;
      }

      final parseStopwatch = Stopwatch()..start();
      debugPrint('[PLAYLIST_DIAGNOSTIC] parsing started lines=$lineCount');

      final List<Channel> channels;
      try {
        channels = M3uParser.parseLines(lines);
        parseStopwatch.stop();
        debugPrint('[PLAYLIST_DIAGNOSTIC] parsing completed elapsedMs=${parseStopwatch.elapsedMilliseconds} channels=${channels.length}');
      } catch (e) {
        debugPrint('[PLAYLIST_DIAGNOSTIC] error stage=m3u_parsing type=${e.runtimeType} message=$e');
        rethrow;
      }

      totalStopwatch.stop();
      debugPrint('[PLAYLIST_DIAGNOSTIC] total elapsedMs=${totalStopwatch.elapsedMilliseconds}');
      return channels;
    } else {
      final errorMsg = 'Falha ao baixar lista M3U. Código de status: ${response.statusCode}';
      debugPrint('[PLAYLIST_DIAGNOSTIC] error stage=http_status status=${response.statusCode} message=$errorMsg');
      throw Exception(errorMsg);
    }
  }
}
