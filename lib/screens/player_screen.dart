import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media_item.dart';
import '../repositories/library_repository.dart';
import '../services/player_connection_manager.dart';
import '../services/media3_player_engine.dart';
import '../services/player_manager.dart';
import '../services/player_engine.dart';
import '../services/vlc_player_engine.dart';
import 'player/widgets/player_gesture_detector.dart';
import 'player/widgets/player_overlay.dart';
import 'player/widgets/player_quick_channel_drawer.dart';
import 'player/widgets/player_sleep_timer_dialog.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem media;
  final List<MediaItem>? playlist;
  final int? initialIndex;
  final LibraryRepository libraryRepository;

  const PlayerScreen({
    super.key,
    required this.media,
    this.playlist,
    this.initialIndex,
    required this.libraryRepository,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerConnectionManager _connectionManager;
  late MediaItem _currentMedia;
  int _currentIndex = 0;
  List<MediaItem> _playlist = [];

  VlcPlayerEngine? _vlcEngine;
  VlcPlayerController? get _controller => _vlcEngine?.controller;
  Media3PlayerEngine? _media3Engine;
  late final PlayerManager _playerManager;
  bool _useMedia3 = true;
  bool _isDisposed = false;
  bool _isOverlayVisible = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _isLocked = false;
  bool _isQuickDrawerOpen = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _aspectRatio = '16:9';
  double _volume = 1.0;
  double _brightness = 0.5;
  double _playbackSpeed = 1.0;

  // Sleep Timer
  int? _sleepTimerMinutes;
  int? _sleepTimerRemainingSeconds;
  Timer? _sleepCountdownTimer;
  Timer? _nextEpisodeTimer;
  int? _nextEpisodeCountdown;
  bool _isAdvancingNextEpisode = false;
  bool _autoPlayNextEpisode = true;

  // Startup Diagnostic Instrumentation
  DateTime? _startupStartedAt;
  bool _startupInitializedLogged = false;
  bool _startupPlayingLogged = false;
  bool? _lastBufferingState;

  int _startupElapsedMs() {
    final startedAt = _startupStartedAt;
    if (startedAt == null) return 0;
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  String _sanitizeStreamUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery && uri.userInfo.isEmpty) return url;
      final params = Map<String, String>.from(uri.queryParameters);
      for (final key in params.keys.toList()) {
        final lower = key.toLowerCase();
        if (lower.contains('pass') ||
            lower.contains('token') ||
            lower.contains('user') ||
            lower.contains('auth') ||
            lower.contains('key') ||
            lower.contains('secret')) {
          params[key] = '***';
        }
      }
      return uri
          .replace(
            userInfo: uri.userInfo.isNotEmpty ? '***:***' : null,
            queryParameters: params.isNotEmpty ? params : null,
          )
          .toString();
    } catch (_) {
      return 'url_redacted';
    }
  }

  String _mediaTypeLabel(MediaItem media) {
    if (media.isLive) return 'LIVE';
    if (media.isMovie) return 'VOD/MOVIE';
    if (media.isSeries) return 'SERIES/EPISODE';
    return media.type.name.toUpperCase();
  }

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _currentMedia = widget.media;
    _playlist = widget.playlist ?? [widget.media];
    _currentIndex = widget.initialIndex ?? _playlist.indexWhere((m) => m.id == _currentMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;

    _connectionManager = PlayerConnectionManager(
      maxRetries: 3,
      baseBackoff: const Duration(seconds: 2),
    );
    _playerManager = PlayerManager();
    _playerManager.bindConnectionManager(_connectionManager);
    _connectionManager.addListener(_onConnectionStatusChanged);

    _enableImmersiveMode();
    _connectStream();
  }

  Future<void> _enableImmersiveMode() async {
    try {
      await WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to enable immersive mode / wakelock: $e');
    }
  }

  Future<void> _restoreSystemUI() async {
    try {
      await WakelockPlus.disable();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to restore system UI: $e');
    }
  }

  void _onConnectionStatusChanged() {
    if (_isDisposed || !mounted) return;
    _safeSetState(() {});
  }

  Future<void> _switchBackend() async {
    if (_isDisposed) return;
    _safeSetState(() => _useMedia3 = !_useMedia3);
    _playerManager.startPlaybackSession();
    debugPrint('[PLAYER_AB_TEST] backend=${_useMedia3 ? 'MEDIA3' : 'VLC'}');
    await _connectStream();
  }

  Future<void> _connectStream() async {
    if (_isDisposed) return;

    _playerManager.startPlaybackSession();
    await _connectionManager.connect((generation) async {
      await _teardownCurrentController();

      if (_isDisposed || generation != _connectionManager.currentGeneration) return;

      _startupStartedAt = DateTime.now();
      _startupInitializedLogged = false;
      _startupPlayingLogged = false;
      _lastBufferingState = null;

      debugPrint('[PLAYER_STARTUP] connection attempt started t=0ms');

      final resumePos = widget.libraryRepository.getResumePosition(_currentMedia.id);

      final streamUrl = _currentMedia.streamUrl;
      final mediaType = _mediaTypeLabel(_currentMedia);
      final sanitizedStreamUrl = _sanitizeStreamUrl(streamUrl);

      debugPrint(
        '[PLAYER_STREAM_DIAGNOSTIC] type=$mediaType '
        'id=${_currentMedia.id} '
        'title=${_currentMedia.title} '
        'url=$sanitizedStreamUrl '
        'urlLength=${streamUrl.length} '
        'empty=${streamUrl.isEmpty} '
        't=${_startupElapsedMs()}ms',
      );

      if (streamUrl.isEmpty) {
        debugPrint(
          '[PLAYER_STREAM_DIAGNOSTIC] ERROR empty stream URL '
          'type=$mediaType id=${_currentMedia.id}',
        );
      }

      try {
        final engine = await _playerManager.initializeWithFallback(
          streamUrl,
          preferredBackend: _useMedia3 ? PlayerBackend.media3 : PlayerBackend.vlc,
        );
        if (engine is Media3PlayerEngine) {
          _useMedia3 = true;
          _media3Engine = engine;
          final controller = engine.videoController!;
          controller.addListener(_onMedia3StateChanged);
          await controller.setVolume(_volume.clamp(0.0, 1.0).toDouble());
          await controller.play();
          debugPrint('[PLAYER_STARTUP] Media3 initialized/playing t=${_startupElapsedMs()}ms');
        } else if (engine is VlcPlayerEngine) {
          _useMedia3 = false;
          _vlcEngine = engine;
          final controller = engine.controller;
          if (controller == null) throw StateError('VLC engine did not expose a controller');
          controller.addListener(_onPlayerStateChanged);
          debugPrint('[PLAYER_STARTUP] VLC engine initialized t=${_startupElapsedMs()}ms');
        } else {
          throw StateError('PlayerManager returned an unsupported engine');
        }
      } catch (e) {
        await _playerManager.disposeActiveEngine();
        _media3Engine = null;
        _vlcEngine = null;
        _connectionManager.onStreamError(e.toString());
        return;
      }
      _safeSetState(() {
        _isBuffering = true;
      });

      // Resume playback position for movies/series using the active backend.
      if (resumePos != null && !_currentMedia.isLive && resumePos.inSeconds > 0) {
        Future<void>.delayed(const Duration(milliseconds: 1200), () async {
          if (_isDisposed || generation != _connectionManager.currentGeneration) return;
          await _seekToSafely(resumePos);
        });
      }

      _startHideTimer();
      widget.libraryRepository.addToHistory(_currentMedia);
    });
  }

  void _onMedia3StateChanged() {
    if (_isDisposed || !mounted || _media3Engine?.videoController == null) return;
    final val = _media3Engine!.videoController!.value;
    if (!_startupInitializedLogged && val.isInitialized) {
      _startupInitializedLogged = true;
      debugPrint('[PLAYER_STARTUP] Media3 initialized t=${_startupElapsedMs()}ms');
    }
    if (val.hasError) {
      _connectionManager.onStreamError(val.errorDescription ?? 'Erro na reprodução Media3');
      return;
    }
    final isPlaying = val.isPlaying;
    final isBuffering = val.isBuffering;
    if (_lastBufferingState != isBuffering) {
      _lastBufferingState = isBuffering;
      debugPrint('[PLAYER_STARTUP] Media3 buffering=$isBuffering t=${_startupElapsedMs()}ms');
    }
    if (!_startupPlayingLogged && isPlaying) {
      _startupPlayingLogged = true;
      debugPrint('[PLAYER_STARTUP] Media3 playing t=${_startupElapsedMs()}ms');
    }
    if (isPlaying) _connectionManager.onStreamConnected();
    _connectionManager.onBufferingState(isBuffering);
    final pos=val.position, dur=val.duration;
    _updateNextEpisodeState(pos, dur, isPlaying);
    if (!_currentMedia.isLive && pos.inSeconds > 5 && isPlaying) {
      widget.libraryRepository.saveResumePosition(_currentMedia.id, pos);
    }
    _safeSetState(() {
      _isPlaying=isPlaying; _isBuffering=isBuffering; _position=pos; _duration=dur;
    });
  }

  void _onPlayerStateChanged() {
    if (_isDisposed || !mounted || _controller == null) return;

    final val = _controller!.value;

    if (!_startupInitializedLogged && val.isInitialized) {
      _startupInitializedLogged = true;
      debugPrint(
        '[PLAYER_STARTUP] VLC initialized '
        't=${_startupElapsedMs()}ms',
      );
    }

    if (val.hasError) {
      final desc = val.errorDescription.isNotEmpty ? val.errorDescription : 'Erro na reprodução do fluxo';
      _connectionManager.onStreamError(desc);
      return;
    }

    final isPlaying = val.isPlaying;
    final isBuffering = val.isBuffering;
    final pos = val.position;
    final dur = val.duration;

    if (_lastBufferingState != isBuffering) {
      _lastBufferingState = isBuffering;
      debugPrint(
        '[PLAYER_STARTUP] buffering=$isBuffering '
        't=${_startupElapsedMs()}ms',
      );
    }

    if (!_startupPlayingLogged && isPlaying) {
      _startupPlayingLogged = true;
      debugPrint(
        '[PLAYER_STARTUP] VLC playing / first playback state '
        't=${_startupElapsedMs()}ms',
      );
    }

    if (isPlaying) {
      _connectionManager.onStreamConnected();
    }

    _connectionManager.onBufferingState(isBuffering);

    _updateNextEpisodeState(pos, dur, isPlaying);

    // Save resume position periodically for VOD
    if (!_currentMedia.isLive && pos.inSeconds > 5 && isPlaying) {
      widget.libraryRepository.saveResumePosition(_currentMedia.id, pos);
    }

    _safeSetState(() {
      _isPlaying = isPlaying;
      _isBuffering = isBuffering;
      _position = pos;
      _duration = dur;
    });
  }

  MediaItem? get _nextEpisode {
    if (!_currentMedia.isSeries || _playlist.isEmpty) return null;
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) return null;
    final candidate = _playlist[nextIndex];
    return candidate.isSeries ? candidate : null;
  }

  void _cancelNextEpisodeCountdown() {
    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = null;
    if (_nextEpisodeCountdown != null) _safeSetState(() => _nextEpisodeCountdown = null);
  }

  void _playNextEpisode() {
    final next = _nextEpisode;
    if (next == null || _isDisposed || _isAdvancingNextEpisode) return;
    _isAdvancingNextEpisode = true;
    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = null;
    _nextEpisodeCountdown = null;
    _switchToMedia(next);
    _isAdvancingNextEpisode = false;
  }

  void _updateNextEpisodeState(Duration position, Duration duration, bool isPlaying) {
    final next = _nextEpisode;
    if (!_currentMedia.isSeries || next == null || duration <= Duration.zero) {
      _cancelNextEpisodeCountdown();
      return;
    }
    final remaining = duration - position;
    if (remaining <= Duration.zero) {
      if (_autoPlayNextEpisode) _playNextEpisode();
      return;
    }
    if (isPlaying && remaining <= const Duration(seconds: 10)) {
      final seconds = remaining.inSeconds.clamp(0, 10);
      if (_nextEpisodeTimer == null) {
        _safeSetState(() => _nextEpisodeCountdown = seconds);
        _nextEpisodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_isDisposed || !mounted) { timer.cancel(); return; }
          final current = _nextEpisodeCountdown;
          if (current == null || current <= 1) {
            timer.cancel();
            _nextEpisodeTimer = null;
            _safeSetState(() => _nextEpisodeCountdown = 0);
            if (_autoPlayNextEpisode) _playNextEpisode();
            return;
          }
          _safeSetState(() => _nextEpisodeCountdown = current - 1);
        });
      }
    } else if (remaining > const Duration(seconds: 10)) {
      _cancelNextEpisodeCountdown();
    }
  }

  Future<void> _initializeCast() async {
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final options = GoogleCastOptionsAndroid(
      appId: appId,
      stopCastingOnAppTerminated: false,
    );
    GoogleCastContext.instance.setSharedInstanceWithOptions(options);
  }

  Future<void> _showCastPicker() async {
    if (_isDisposed || !mounted) return;
    try {
      await _initializeCast();
      GoogleCastDiscoveryManager.instance.startDiscovery();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        builder: (sheetContext) => SafeArea(
          child: StreamBuilder<List<GoogleCastDevice>>(
            stream: GoogleCastDiscoveryManager.instance.devicesStream,
            initialData: const <GoogleCastDevice>[],
            builder: (context, snapshot) {
              final devices = snapshot.data ?? const <GoogleCastDevice>[];
              return SizedBox(
                height: 320,
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.cast, color: Colors.white),
                      title: Text('Transmitir para', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(color: Colors.white24),
                    if (devices.isEmpty)
                      const Expanded(child: Center(child: Text('Procurando dispositivos Chromecast...', style: TextStyle(color: Colors.white70))))
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (_, index) {
                            final device = devices[index];
                            return ListTile(
                              leading: const Icon(Icons.tv, color: Colors.redAccent),
                              title: Text(device.friendlyName, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(device.modelName ?? 'Chromecast', style: const TextStyle(color: Colors.white54)),
                              onTap: () async {
                                try {
                                  await GoogleCastSessionManager.instance.startSessionWithDevice(device);
                                  final uri = Uri.parse(_currentMedia.streamUrl);
                                  final path = uri.path.toLowerCase();
                                  final contentType = path.endsWith('.m3u8') ? 'application/x-mpegURL' : path.endsWith('.webm') ? 'video/webm' : 'video/mp4';
                                  final info = GoogleCastMediaInformation(
                                    contentId: _currentMedia.id,
                                    streamType: _currentMedia.isLive ? CastMediaStreamType.live : CastMediaStreamType.buffered,
                                    contentUrl: uri,
                                    contentType: contentType,
                                    duration: _currentMedia.duration,
                                    metadata: GoogleCastMovieMediaMetadata(
                                      title: _currentMedia.title,
                                      subtitle: _currentMedia.isLive ? 'AO VIVO' : 'Best Player',
                                      images: _currentMedia.posterUrl == null ? null : [GoogleCastImage(url: Uri.parse(_currentMedia.posterUrl!))],
                                    ),
                                  );
                                  await GoogleCastRemoteMediaClient.instance.loadMedia(
                                    info,
                                    autoPlay: true,
                                    playPosition: _position,
                                  );
                                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transmitindo para ' + device.friendlyName)));
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha no Chromecast: ' + e.toString())));
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      GoogleCastDiscoveryManager.instance.stopDiscovery();
    } catch (e) {
      GoogleCastDiscoveryManager.instance.stopDiscovery();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível usar o Chromecast: ' + e.toString())));
    }
  }

  Future<void> _teardownCurrentController() async {
    if (_vlcEngine != null) {
      try { _vlcEngine!.controller?.removeListener(_onPlayerStateChanged); } catch (_) {}
      _vlcEngine = null;
    }
    if (_media3Engine != null) {
      try { _media3Engine!.videoController?.removeListener(_onMedia3StateChanged); } catch (_) {}
      _media3Engine = null;
    }
    await _playerManager.disposeActiveEngine();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed && mounted) {
        _safeSetState(() {
          _isOverlayVisible = false;
        });
      }
    });
  }

  void _toggleOverlay() {
    if (_isDisposed || !mounted) return;
    _safeSetState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    if (_isOverlayVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  void _togglePlayPause() {
    if (_isDisposed) return;
    if (_useMedia3) { final c=_media3Engine?.videoController; if(c==null)return; c.value.isPlaying ? c.pause() : c.play(); _startHideTimer(); return; }
    if (_controller == null) return;
    try {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error toggling play/pause: $e');
    }
    _startHideTimer();
  }

  Future<bool> _seekToSafely(Duration requested) async {
    if (_isDisposed || _currentMedia.isLive) return false;
    final deadline = DateTime.now().add(const Duration(seconds: 60));

    try {
      while (!_isDisposed && DateTime.now().isBefore(deadline)) {
        if (_useMedia3) {
          final controller = _media3Engine?.videoController;
          if (controller != null && controller.value.isInitialized) {
            final duration = controller.value.duration;
            final target = duration > Duration.zero
                ? (requested < Duration.zero
                    ? Duration.zero
                    : (requested > duration ? duration : requested))
                : (requested < Duration.zero ? Duration.zero : requested);
            await controller.seekTo(target);
            return true;
          }
        } else {
          final controller = _controller;
          if (controller != null && controller.value.isInitialized) {
            final duration = controller.value.duration;
            final target = duration > Duration.zero
                ? (requested < Duration.zero
                    ? Duration.zero
                    : (requested > duration ? duration : requested))
                : (requested < Duration.zero ? Duration.zero : requested);
            await controller.seekTo(target);
            return true;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      debugPrint('[PlayerScreen] Seek timeout after 60 seconds');
    } catch (e) {
      debugPrint('[PlayerScreen] Seek failed: $e');
    }
    return false;
  }

  void _seekBy(Duration offset) {
    if (_isDisposed || _currentMedia.isLive) return;
    final target = _position + offset;
    _seekToSafely(target);
    _startHideTimer();
  }

  void _onSeek(Duration target) {
    if (_isDisposed || _currentMedia.isLive) return;
    _seekToSafely(target);
    _startHideTimer();
  }

  void _toggleAspectRatio() {
    if (_isDisposed) return;
    const aspects = ['16:9', '4:3', 'FILL', 'FIT'];
    final currentIndex = aspects.indexOf(_aspectRatio);
    final nextIndex = (currentIndex + 1) % aspects.length;
    _safeSetState(() {
      _aspectRatio = aspects[nextIndex];
    });
    _startHideTimer();
  }

  void _togglePlaybackSpeed() {
    if (_isDisposed || _currentMedia.isLive) return;
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];

    _safeSetState(() {
      _playbackSpeed = newSpeed;
    });

    try {
      if (_useMedia3) {
        final controller = _media3Engine?.videoController;
        if (controller != null) {
          unawaited(
            controller.setPlaybackSpeed(newSpeed).catchError((error) {
              debugPrint('[PlayerScreen] Media3 playback speed error: $error');
            }),
          );
        }
      } else {
        _controller?.setPlaybackSpeed(newSpeed);
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error setting playback speed: $e');
    }
    _startHideTimer();
  }

  void _switchToMedia(MediaItem media) {
    if (_isDisposed) return;
    // Save current resume position if VOD
    if (!_currentMedia.isLive && _position.inSeconds > 5) {
      widget.libraryRepository.saveResumePosition(_currentMedia.id, _position);
    }

    _cancelNextEpisodeCountdown();
    _safeSetState(() {
      _currentMedia = media;
      _currentIndex = _playlist.indexWhere((m) => m.id == media.id);
      if (_currentIndex < 0) _currentIndex = 0;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    _connectStream();
  }

  void _playNext() {
    if (_playlist.isEmpty) return;
    final nextIdx = (_currentIndex + 1) % _playlist.length;
    _switchToMedia(_playlist[nextIdx]);
  }

  void _playPrevious() {
    if (_playlist.isEmpty) return;
    final prevIdx = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    _switchToMedia(_playlist[prevIdx]);
  }

  void _showSleepTimerDialog() {
    if (_isDisposed || !mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSleepTimerDialog(
        currentMinutes: _sleepTimerMinutes,
        onSelected: (minutes) {
          _setSleepTimer(minutes);
        },
      ),
    );
  }

  void _setSleepTimer(int? minutes) {
    _sleepCountdownTimer?.cancel();
    _sleepCountdownTimer = null;

    if (minutes == null) {
      _safeSetState(() {
        _sleepTimerMinutes = null;
        _sleepTimerRemainingSeconds = null;
      });
      return;
    }

    final totalSeconds = minutes * 60;
    _safeSetState(() {
      _sleepTimerMinutes = minutes;
      _sleepTimerRemainingSeconds = totalSeconds;
    });

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      if (_sleepTimerRemainingSeconds != null && _sleepTimerRemainingSeconds! > 1) {
        _safeSetState(() {
          _sleepTimerRemainingSeconds = _sleepTimerRemainingSeconds! - 1;
        });
      } else {
        timer.cancel();
        _safeSetState(() {
          _sleepTimerMinutes = null;
          _sleepTimerRemainingSeconds = null;
        });
        _teardownCurrentController();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Temporizador de sono atingido. Reprodução encerrada.')),
          );
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  void _showAudioTrackSelector() async {
    if (_isDisposed || _controller == null) return;
    try {
      final tracks = await _controller!.getAudioTracks();
      if (_isDisposed || !mounted || tracks.isEmpty) return;

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.grey[900],
          builder: (ctx) {
            return ListView(
              shrinkWrap: true,
              children: tracks.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (!_isDisposed && _controller != null) {
                      _controller!.setAudioTrack(entry.key);
                    }
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error fetching audio tracks: $e');
    }
  }

  void _showSubtitleSelector() async {
    if (_isDisposed || _controller == null) return;
    try {
      final subtitles = await _controller!.getSpuTracks();
      if (_isDisposed || !mounted || subtitles.isEmpty) return;

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.grey[900],
          builder: (ctx) {
            return ListView(
              shrinkWrap: true,
              children: subtitles.entries.map((entry) {
                return ListTile(
                  title: Text(entry.value, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    if (!_isDisposed && _controller != null) {
                      _controller!.setSpuTrack(entry.key);
                    }
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error fetching subtitles: $e');
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideTimer?.cancel();
    _hideTimer = null;
    _sleepCountdownTimer?.cancel();
    _sleepCountdownTimer = null;
    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = null;

    // Flush any pending debounced position immediately before disposing
    if (!_currentMedia.isLive && _position.inSeconds > 5) {
      widget.libraryRepository.saveResumePosition(_currentMedia.id, _position);
      widget.libraryRepository.flushResumePositions();
    }

    _connectionManager.removeListener(_onConnectionStatusChanged);
    _connectionManager.dispose();

    _teardownCurrentController();
    _playerManager.dispose();
    _restoreSystemUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _connectionManager.isFailed;
    final isReconnecting = _connectionManager.isReconnecting;
    final errorMessage = _connectionManager.errorMessage;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PlayerGestureDetector(
        isLocked: _isLocked,
        isLive: _currentMedia.isLive,
        currentVolume: _volume,
        currentBrightness: _brightness,
        onTap: _toggleOverlay,
        onDoubleTapLeft: () => _seekBy(const Duration(seconds: -10)),
        onDoubleTapRight: () => _seekBy(const Duration(seconds: 10)),
        onVolumeChange: (newVol) {
          _volume = newVol;
          try {
            if (_useMedia3) { _media3Engine?.videoController?.setVolume(newVol.clamp(0.0,1.0).toDouble()); } else { _controller?.setVolume((newVol * 100).toInt()); }
          } catch (_) {}
        },
        onBrightnessChange: (newBrightness) {
          _safeSetState(() {
            _brightness = newBrightness;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video surface
            if (_useMedia3 && _media3Engine?.videoController != null && !hasError)
              Center(child: AspectRatio(aspectRatio: _aspectRatio == '4:3' ? 4/3 : 16/9, child: VideoPlayer(_media3Engine!.videoController!)))
            else if (_controller != null && !hasError)
              Center(
                child: VlcPlayer(
                  controller: _controller!,
                  aspectRatio: _aspectRatio == '16:9'
                      ? 16 / 9
                      : (_aspectRatio == '4:3' ? 4 / 3 : 16 / 9),
                  placeholder: const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              ),

            // Brightness Overlay Filter
            if (_brightness < 1.0)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: (1.0 - _brightness) * 0.7),
                ),
              ),

            // Reconnecting Banner Overlay
            if (isReconnecting && !hasError)
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            errorMessage.isNotEmpty ? errorMessage : 'Reconectando...',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Error Overlay
            if (hasError)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          _connectStream();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),

            if (_nextEpisode != null && _isOverlayVisible)
              Positioned(
                right: 20,
                bottom: 78,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_nextEpisode!.posterUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(_nextEpisode!.posterUrl!, width: 64, height: 42, fit: BoxFit.cover),
                          ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('PRÓXIMO EPISÓDIO', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(_nextEpisode!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              if (_nextEpisodeCountdown != null && _nextEpisodeCountdown! > 0)
                                Text('Reproduzindo em ' + _nextEpisodeCountdown.toString() + 's', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(_autoPlayNextEpisode ? Icons.autorenew : Icons.stop_circle_outlined, color: Colors.white70),
                          tooltip: _autoPlayNextEpisode ? 'Desativar reprodução automática' : 'Ativar reprodução automática',
                          onPressed: () {
                            _safeSetState(() => _autoPlayNextEpisode = !_autoPlayNextEpisode);
                            if (!_autoPlayNextEpisode) _cancelNextEpisodeCountdown();
                          },
                        ),
                        TextButton(onPressed: _playNextEpisode, child: const Text('PRÓXIMO')),
                      ],
                    ),
                  ),
                ),
              ),

            // HUD Overlay
            PlayerOverlay(
              visible: _isOverlayVisible,
              isLocked: _isLocked,
              media: _currentMedia,
              isPlaying: _isPlaying,
              isBuffering: _isBuffering || isReconnecting,
              position: _position,
              duration: _duration,
              currentAspect: _aspectRatio,
              currentSpeed: _playbackSpeed,
              sleepTimerRemainingSeconds: _sleepTimerRemainingSeconds,
              onBack: () => Navigator.of(context).pop(),
              onPlayPause: _togglePlayPause,
              onRewind: () => _seekBy(const Duration(seconds: -10)),
              onForward: () => _seekBy(const Duration(seconds: 10)),
              onSeek: _onSeek,
              onToggleAspect: _toggleAspectRatio,
              onAudioTrack: _useMedia3 ? null : _showAudioTrackSelector,
              onSubtitles: _useMedia3 ? null : _showSubtitleSelector,
              onSleepTimer: _showSleepTimerDialog,
              onLock: () {
                _safeSetState(() => _isLocked = true);
                _startHideTimer();
              },
              onUnlock: () {
                _safeSetState(() => _isLocked = false);
                _startHideTimer();
              },
              onQuickChannels: _playlist.length > 1
                  ? () {
                      _safeSetState(() => _isQuickDrawerOpen = true);
                    }
                  : null,
              onPrevious: _playlist.length > 1 ? _playPrevious : null,
              onNext: _playlist.length > 1 ? _playNext : null,
              onToggleSpeed: !_currentMedia.isLive ? _togglePlaybackSpeed : null,
              onUserInteraction: _toggleOverlay,
              onToggleBackend: _switchBackend,
              backendLabel: _useMedia3 ? 'Media3' : 'VLC',
            ),

            Positioned(
              top: 18,
              right: 18,
              child: AnimatedOpacity(
                opacity: _isOverlayVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_isOverlayVisible,
                  child: IconButton(
                    icon: const Icon(Icons.cast, color: Colors.white),
                    tooltip: 'Chromecast',
                    onPressed: _showCastPicker,
                  ),
                ),
              ),
            ),

            // Quick Channel Switcher Drawer
            if (_isQuickDrawerOpen)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: PlayerQuickChannelDrawer(
                  playlist: _playlist,
                  currentMedia: _currentMedia,
                  onSelectMedia: _switchToMedia,
                  onClose: () {
                    _safeSetState(() => _isQuickDrawerOpen = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
