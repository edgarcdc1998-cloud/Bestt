class Episode {
  final String id;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String streamUrl;
  final String? coverUrl;
  final String? plot;
  final String? duration;
  final String? containerExtension;

  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.streamUrl,
    this.coverUrl,
    this.plot,
    this.duration,
    this.containerExtension,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'title': title,
        'streamUrl': streamUrl,
        'coverUrl': coverUrl,
        'plot': plot,
        'duration': duration,
        'containerExtension': containerExtension,
      };

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: json['id']?.toString() ?? '',
        seriesId: json['seriesId']?.toString() ?? '',
        seasonNumber: json['seasonNumber'] is int
            ? json['seasonNumber'] as int
            : int.tryParse(json['seasonNumber']?.toString() ?? '1') ?? 1,
        episodeNumber: json['episodeNumber'] is int
            ? json['episodeNumber'] as int
            : int.tryParse(json['episodeNumber']?.toString() ?? '1') ?? 1,
        title: json['title'] as String? ?? 'Episódio',
        streamUrl: json['streamUrl'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
        plot: json['plot'] as String?,
        duration: json['duration'] as String?,
        containerExtension: json['containerExtension'] as String?,
      );
}
