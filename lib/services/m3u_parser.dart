import 'dart:convert';
import '../models/channel.dart';

class M3uParser {
  // Regex to extract key-value attributes supporting double quotes, single quotes, and unquoted values
  static final RegExp _attributeRegex = RegExp(
    r'''([\w\-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^,\s]+))''',
    caseSensitive: false,
  );

  /// Existing public API: Parses full M3U content string.
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
      var line = rawLine.trim();
      if (line.isEmpty) continue;

      // Strip UTF-8 Byte Order Mark (BOM) if present at line start
      if (line.startsWith('\uFEFF')) {
        line = line.substring(1).trim();
        if (line.isEmpty) continue;
      }

      if (line.startsWith('#EXTINF:')) {
        // A new declaration supersedes an unfinished entry. Resetting here
        // prevents attributes from a malformed previous entry leaking forward.
        currentName = null;
        currentLogo = null;
        currentTvgId = null;
        currentTvgName = null;
        currentCategory = null;
        currentId = null;

        final commaIndex = line.lastIndexOf(',');
        final attributesPart = commaIndex != -1 ? line.substring(0, commaIndex) : line;

        // Extract all attributes via single regex iteration
        final matches = _attributeRegex.allMatches(attributesPart);
        for (final match in matches) {
          final key = match.group(1)?.toLowerCase();
          final val = (match.group(2) ?? match.group(3) ?? match.group(4))?.trim();
          if (val == null || val.isEmpty) continue;

          switch (key) {
            case 'tvg-id':
              currentTvgId = val;
              break;
            case 'tvg-name':
              currentTvgName = val;
              break;
            case 'tvg-logo':
              currentLogo = val;
              break;
            case 'group-title':
              currentCategory = val;
              break;
          }
        }

        // Extract channel name (after last comma)
        if (commaIndex != -1 && commaIndex < line.length - 1) {
          final extractedName = line.substring(commaIndex + 1).trim();
          currentName = extractedName.isNotEmpty ? extractedName : (currentTvgName ?? 'Canal ${channels.length + 1}');
        } else {
          currentName = currentTvgName ?? 'Canal ${channels.length + 1}';
        }
        currentId = currentTvgId ?? 'channel_${channels.length + 1}';
      } else if (line.startsWith('#EXTGRP:')) {
        final grp = line.substring(8).trim();
        if (grp.isNotEmpty) {
          currentCategory = grp;
        }
      } else if (!line.startsWith('#')) {
        // Check for stream URLs
        final lower = line.toLowerCase();
        if (lower.startsWith('http://') ||
            lower.startsWith('https://') ||
            lower.startsWith('rtmp://') ||
            lower.startsWith('rtsp://') ||
            lower.startsWith('udp://') ||
            lower.startsWith('mms://') ||
            lower.startsWith('rtmpe://') ||
            lower.startsWith('hls://')) {
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
    }

    return channels;
  }
}
