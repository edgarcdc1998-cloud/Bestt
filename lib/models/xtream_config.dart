class XtreamConfig {
  final String serverUrl;
  final String username;
  final String password;

  const XtreamConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  String get sanitizedServerUrl {
    var url = serverUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  String get playerApiUrl => '$sanitizedServerUrl/player_api.php?username=$username&password=$password';

  String get liveCategoriesUrl => '$playerApiUrl&action=get_live_categories';
  String get liveStreamsUrl => '$playerApiUrl&action=get_live_streams';
  String get vodCategoriesUrl => '$playerApiUrl&action=get_vod_categories';
  String get vodStreamsUrl => '$playerApiUrl&action=get_vod_streams';
  String get seriesCategoriesUrl => '$playerApiUrl&action=get_series_categories';
  String get seriesUrl => '$playerApiUrl&action=get_series';

  String seriesInfoUrl(int seriesId) => '$playerApiUrl&action=get_series_info&series_id=$seriesId';
  String shortEpgUrl(int streamId, {int limit = 10}) => '$playerApiUrl&action=get_short_epg&stream_id=$streamId&limit=$limit';
  String fullEpgUrl() => '$sanitizedServerUrl/xmltv.php?username=$username&password=$password';

  String liveStreamUrl(int streamId, {String extension = 'ts'}) =>
      '$sanitizedServerUrl/live/$username/$password/$streamId.$extension';

  String movieStreamUrl(int streamId, {String extension = 'mp4'}) =>
      '$sanitizedServerUrl/movie/$username/$password/$streamId.$extension';

  String seriesStreamUrl(int streamId, {String extension = 'mp4'}) =>
      '$sanitizedServerUrl/series/$username/$password/$streamId.$extension';

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };

  factory XtreamConfig.fromJson(Map<String, dynamic> json) => XtreamConfig(
        serverUrl: json['serverUrl'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XtreamConfig &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode => serverUrl.hashCode ^ username.hashCode ^ password.hashCode;
}
