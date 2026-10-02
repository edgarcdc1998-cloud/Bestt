import '../models/channel.dart';

class M3uParser {
  static List<Channel> parse(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');

    String? currentName;
    String? currentLogo;
    String? currentTvgId;
    String? currentTvgName;
    String? currentCategory;
    String? currentId;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // Extract attributes
        currentTvgId = _extractAttribute(line, 'tvg-id');
        currentTvgName = _extractAttribute(line, 'tvg-name');
        currentLogo = _extractAttribute(line, 'tvg-logo');
        currentCategory = _extractAttribute(line, 'group-title');

        // Extract channel name (after last comma)
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1 && commaIndex < line.length - 1) {
          currentName = line.substring(commaIndex + 1).trim();
        } else {
          currentName = currentTvgName ?? 'Canal ${channels.length + 1}';
        }
        currentId = currentTvgId ?? 'channel_${channels.length + 1}';
      } else if (!line.startsWith('#') && (line.startsWith('http://') || line.startsWith('https://') || line.startsWith('rtmp://') || line.startsWith('rtsp://'))) {
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

  static String? _extractAttribute(String line, String attributeName) {
    final pattern = RegExp('$attributeName="([^"]*)"', caseSensitive: false);
    final match = pattern.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      final val = match.group(1)?.trim();
      return (val != null && val.isNotEmpty) ? val : null;
    }
    return null;
  }
}
