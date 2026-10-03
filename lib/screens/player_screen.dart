import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media_item.dart';
import '../repositories/library_repository.dart';
import '../services/player_connection_manager.dart';
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

  VlcPlayerController? _controller;
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

  Future<void> _connectStream() async {
    if (_isDisposed) return;

    await _connectionManager.connect((generation) async {
      await _teardownCurrentController();

      if (_isDisposed || generation != _connectionManager.currentGeneration) return;

      _startupStartedAt = DateTime.now();
      _startupInitializedLogged = false;
      _startupPlayingLogged = false;
      _lastBufferingState = null;

      debugPrint('[PLAYER_STARTUP] connection attempt started t=0ms');

      final resumePos = widget.libraryRepository.getResumePosition(_currentMedia.id);

      debugPrint(
        '[PLAYER_STARTUP] creating VLC controller '
        't=${_startupElapsedMs()}ms',
      );

      final controller = VlcPlayerController.network(
        _currentMedia.streamUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--network-caching=1500',
            '--live-caching=1500',
          ]),
          http: VlcHttpOptions([
            '--http-reconnect',
          ]),
          rtp: VlcRtpOptions([
            '--rtsp-tcp',
          ]),
        ),
      );

      if (_isDisposed || generation != _connectionManager.currentGeneration) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      _controller = controller;
      _controller!.addListener(_onPlayerStateChanged);

      debugPrint(
        '[PLAYER_STARTUP] VLC controller created/listener attached '
        't=${_startupElapsedMs()}ms',
      );

      _safeSetState(() {
        _isBuffering = true;
      });

      // Apply initial playback speed and volume
      try {
        await _controller!.setPlaybackSpeed(_playbackSpeed);
        await _controller!.setVolume((_volume * 100).toInt());
      } catch (_) {}

      // Resume playback position for movies/series
      if (resumePos != null && !_currentMedia.isLive && resumePos.inSeconds > 0) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!_isDisposed &&
              _controller != null &&
              _controller!.value.isInitialized &&
              generation == _connectionManager.currentGeneration) {
            try {
              _controller!.seekTo(resumePos);
            } catch (e) {
              debugPrint('[PlayerScreen] Error seeking to resume position: $e');
            }
          }
        });
      }

      _startHideTimer();
      widget.libraryRepository.addToHistory(_currentMedia);
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

  Future<void> _teardownCurrentController() async {
    if (_controller != null) {
      try {
        _controller!.removeListener(_onPlayerStateChanged);
        if (_controller!.value.isPlaying) {
          await _controller!.stop();
        }
      } catch (e) {
        debugPrint('[PlayerScreen] Error during controller stop/removeListener: $e');
      }
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('[PlayerScreen] Error disposing controller: $e');
      }
      _controller = null;
    }
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
    if (_isDisposed || _controller == null) return;
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

  void _seekBy(Duration offset) {
    if (_isDisposed || _controller == null || _currentMedia.isLive) return;
    try {
      final target = _position + offset;
      final clamped = target < Duration.zero ? Duration.zero : (target > _duration ? _duration : target);
      _controller!.seekTo(clamped);
    } catch (e) {
      debugPrint('[PlayerScreen] Error seeking: $e');
    }
    _startHideTimer();
  }

  void _onSeek(Duration target) {
    if (_isDisposed || _controller == null || _currentMedia.isLive) return;
    try {
      _controller!.seekTo(target);
    } catch (e) {
      debugPrint('[PlayerScreen] Error seeking: $e');
    }
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
    if (_isDisposed || _controller == null || _currentMedia.isLive) return;
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    final newSpeed = speeds[nextIndex];

    _safeSetState(() {
      _playbackSpeed = newSpeed;
    });

    try {
      _controller!.setPlaybackSpeed(newSpeed);
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

    // Flush any pending debounced position immediately before disposing
    if (!_currentMedia.isLive && _position.inSeconds > 5) {
      widget.libraryRepository.saveResumePosition(_currentMedia.id, _position);
      widget.libraryRepository.flushResumePositions();
    }

    _connectionManager.removeListener(_onConnectionStatusChanged);
    _connectionManager.dispose();

    _teardownCurrentController();
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
            _controller?.setVolume((newVol * 100).toInt());
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
            // VLC Video Surface
            if (_controller != null && !hasError)
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
              onAudioTrack: _showAudioTrackSelector,
              onSubtitles: _showSubtitleSelector,
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
