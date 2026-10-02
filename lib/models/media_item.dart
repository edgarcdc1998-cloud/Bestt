import 'playback_type.dart';

class MediaItem {
  final String id;
  final String title;
  final String streamUrl;
  final PlaybackType type;
  final String? posterUrl;
  final String? backdropUrl;
  final String? categoryId;
  final String? categoryName;
  final String? description;
  final Duration? duration;
  final Duration? resumePosition;
  final int? streamId;
  final String? containerExtension;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;

  const MediaItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.type,
    this.posterUrl,
    this.backdropUrl,
    this.categoryId,
    this.categoryName,
    this.description,
    this.duration,
    this.resumePosition,
    this.streamId,
    this.containerExtension,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
  });

  bool get isLive => type == PlaybackType.live;
  bool get isMovie => type == PlaybackType.movie || type == PlaybackType.vod;
  bool get isSeries => type == PlaybackType.series;

  MediaItem copyWith({
    String? id,
    String? title,
    String? streamUrl,
    PlaybackType? type,
    String? posterUrl,
    String? backdropUrl,
    String? categoryId,
    String? categoryName,
    String? description,
    Duration? duration,
    Duration? resumePosition,
    int? streamId,
    String? containerExtension,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      type: type ?? this.type,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      resumePosition: resumePosition ?? this.resumePosition,
      streamId: streamId ?? this.streamId,
      containerExtension: containerExtension ?? this.containerExtension,
      seriesId: seriesId ?? this.seriesId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'streamUrl': streamUrl,
        'type': type.name,
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'description': description,
        'durationMs': duration?.inMilliseconds,
        'resumePositionMs': resumePosition?.inMilliseconds,
        'streamId': streamId,
        'containerExtension': containerExtension,
        'seriesId': seriesId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    PlaybackType parseType(String? val) {
      if (val == null) return PlaybackType.live;
      return PlaybackType.values.firstWhere(
        (e) => e.name == val,
        orElse: () => PlaybackType.live,
      );
    }

    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Sem Título',
      streamUrl: json['streamUrl'] as String? ?? '',
      type: parseType(json['type'] as String?),
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName'] as String?,
      description: json['description'] as String?,
      duration: json['durationMs'] != null ? Duration(milliseconds: json['durationMs'] as int) : null,
      resumePosition: json['resumePositionMs'] != null ? Duration(milliseconds: json['resumePositionMs'] as int) : null,
      streamId: json['streamId'] is int ? json['streamId'] as int : int.tryParse(json['streamId']?.toString() ?? ''),
      containerExtension: json['containerExtension'] as String?,
      seriesId: json['seriesId']?.toString(),
      seasonNumber: json['seasonNumber'] is int ? json['seasonNumber'] as int : int.tryParse(json['seasonNumber']?.toString() ?? ''),
      episodeNumber: json['episodeNumber'] is int ? json['episodeNumber'] as int : int.tryParse(json['episodeNumber']?.toString() ?? ''),
    );
  }
}
