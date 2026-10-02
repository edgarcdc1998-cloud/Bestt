import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/xtream_config.dart';
import '../services/app_storage.dart';
import '../services/playlist_service.dart';
import '../services/xtream_service.dart';

enum AuthType {
  none,
  xtream,
  m3u,
}

class AuthenticationRepository extends ChangeNotifier {
  final AppStorage _storage;
  final XtreamService _xtreamService;
  final PlaylistService _playlistService;

  AuthType _authType = AuthType.none;
  XtreamConfig? _xtreamConfig;
  String? _m3uUrl;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _serverInfo;

  AuthenticationRepository(
    this._storage, {
    XtreamService? xtreamService,
    PlaylistService? playlistService,
  })  : _xtreamService = xtreamService ?? XtreamService(),
        _playlistService = playlistService ?? PlaylistService();

  AuthType get authType => _authType;
  XtreamConfig? get xtreamConfig => _xtreamConfig;
  String? get m3uUrl => _m3uUrl;
  Map<String, dynamic>? get userInfo => _userInfo;
  Map<String, dynamic>? get serverInfo => _serverInfo;
  bool get isAuthenticated => _authType != AuthType.none;

  Future<void> init() async {
    final savedType = _storage.getString('auth_type');
    if (savedType == 'xtream') {
      final configJson = _storage.getJsonMap('xtream_config');
      if (configJson != null) {
        _xtreamConfig = XtreamConfig.fromJson(configJson);
        _authType = AuthType.xtream;
        _userInfo = _storage.getJsonMap('user_info');
        _serverInfo = _storage.getJsonMap('server_info');
      }
    } else if (savedType == 'm3u') {
      final url = _storage.getString('m3u_url');
      if (url != null && url.isNotEmpty) {
        _m3uUrl = url;
        _authType = AuthType.m3u;
      }
    }
    notifyListeners();
  }

  Future<bool> loginXtream(String serverUrl, String username, String password) async {
    final config = XtreamConfig(serverUrl: serverUrl, username: username, password: password);
    final response = await _xtreamService.authenticate(config);
    _userInfo = response['user_info'] as Map<String, dynamic>?;
    _serverInfo = response['server_info'] as Map<String, dynamic>?;
    _xtreamConfig = config;
    _authType = AuthType.xtream;

    await _storage.setString('auth_type', 'xtream');
    await _storage.setJson('xtream_config', config.toJson());
    if (_userInfo != null) await _storage.setJson('user_info', _userInfo);
    if (_serverInfo != null) await _storage.setJson('server_info', _serverInfo);

    notifyListeners();
    return true;
  }

  Future<bool> loginM3u(String url) async {
    // Validate by fetching channels
    await _playlistService.fetchPlaylist(url);
    _m3uUrl = url;
    _authType = AuthType.m3u;

    await _storage.setString('auth_type', 'm3u');
    await _storage.setString('m3u_url', url);

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _authType = AuthType.none;
    _xtreamConfig = null;
    _m3uUrl = null;
    _userInfo = null;
    _serverInfo = null;

    await _storage.remove('auth_type');
    await _storage.remove('xtream_config');
    await _storage.remove('user_info');
    await _storage.remove('server_info');
    await _storage.remove('m3u_url');

    notifyListeners();
  }
}
