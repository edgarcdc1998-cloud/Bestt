import 'dart:convert';
import '../models/channel.dart';

class M3uParser {
  // Pre-compiled regular expressions for high-frequency attribute extraction (ETAPA 4B)
  static final RegExp _tvgIdRegex = RegExp(r'tvg-id="([^"]*)"', caseSensitive: false);
  static final RegExp _tvgNameRegex = RegExp(r'tvg-name="([^"]*)"', caseSensitive: false);
  static final RegExp _tvgLogoRegex = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false);
  static final RegExp _groupTitleRegex = RegExp(r'group-title="([^"]*)"', caseSensitive: false);

  /// Existing public API: Parses full M3U content string without allocating intermediate List<String>.
  static List<Channel> parse(String content) {
    if (content.isEmpty) return [];
    return parseLines(LineSplitter.split(content));
  }

  /// Line-by-line parser accepting any lazy or eager Iterable<String>.
  static List<Channel> parseLines(Iterable<String> lines) {
    final List<Channel> channels = [];

    String? currentName;
    String? currentLogo;
    String? currentTvgId;
    String? currentTvgName;
    String? currentCategory;
    String? currentId;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // Extract attributes using pre-compiled regexes
        currentTvgId = _extractAttribute(line, _tvgIdRegex);
        currentTvgName = _extractAttribute(line, _tvgNameRegex);
        currentLogo = _extractAttribute(line, _tvgLogoRegex);
        currentCategory = _extractAttribute(line, _groupTitleRegex);

        // Extract channel name (after last comma)
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex < line.length - 1) {
          currentName = line.substring(commaIndex + 1).trim();
        } else {
          currentName = currentTvgName ?? 'Canal ${channels.length + 1}';
        }
        currentId = currentTvgId ?? 'channel_${channels.length + 1}';
      } else if (!line.startsWith('#') &&
          (line.startsWith('http://') ||
              line.startsWith('https://') ||
              line.startsWith('rtmp://') ||
              line.startsWith('rtsp://'))) {
        if (currentName != null) {
          channels.add(
            Channel(
              id: currentId ?? 'channel_${channels.length + 1}',
              name: currentName,
              streamUrl: line,
              logoUrl: currentLogo,
              categoryId: currentCategory ?? 'Geral',
              categoryName: currentCategory ?? 'Geral',
              tvgId: currentTvgId,
              tvgName: currentTvgName,
            ),
          );
        }
        // Reset state for next entry
        currentName = null;
        currentLogo = null;
        currentTvgId = null;
        currentTvgName = null;
        currentCategory = null;
        currentId = null;
      }
    }

    return channels;
  }

  static String? _extractAttribute(String line, RegExp regex) {
    final match = regex.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      final val = match.group(1)?.trim();
      return (val != null && val.isNotEmpty) ? val : null;
    }
    return null;
  }
}
