import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media_item.dart';
import '../repositories/library_repository.dart';
import 'player/widgets/player_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem media;
  final LibraryRepository libraryRepository;

  const PlayerScreen({
    super.key,
    required this.media,
    required this.libraryRepository,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VlcPlayerController? _controller;
  bool _isDisposed = false;
  bool _isOverlayVisible = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _aspectRatio = '16:9';

  Timer? _hideTimer;
  Timer? _reconnectTimer;
  Timer? _bufferTimer;

  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _enableImmersiveMode();
    _initPlayer();
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

  void _cancelAllTimers() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _bufferTimer?.cancel();
    _bufferTimer = null;
  }

  Future<void> _initPlayer() async {
    if (_isDisposed) return;

    _cancelAllTimers();

    final resumePos = widget.libraryRepository.getResumePosition(widget.media.id);

    try {
      final controller = VlcPlayerController.network(
        widget.media.streamUrl,
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

      if (_isDisposed) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      _controller = controller;
      _controller!.addListener(_onPlayerStateChanged);

      _safeSetState(() {
        _isBuffering = true;
        _hasError = false;
        _errorMessage = '';
      });

      // Resume playback position for movies/series
      if (resumePos != null && !widget.media.isLive && resumePos.inSeconds > 0) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!_isDisposed && _controller != null && _controller!.value.isInitialized) {
            try {
              _controller!.seekTo(resumePos);
            } catch (e) {
              debugPrint('[PlayerScreen] Error seeking to resume position: $e');
            }
          }
        });
      }

      _startHideTimer();
      _startBufferTimeoutMonitor();

      // Record to history
      widget.libraryRepository.addToHistory(widget.media);
    } catch (e) {
      debugPrint('[PlayerScreen] Error creating VlcPlayerController: $e');
      _handlePlaybackError('Falha ao inicializar player: $e');
    }
  }

  void _onPlayerStateChanged() {
    if (_isDisposed || !mounted || _controller == null) return;

    final val = _controller!.value;

    if (val.hasError) {
      _handlePlaybackError(val.errorDescription.isNotEmpty ? val.errorDescription : 'Erro de reprodução');
      return;
    }

    final isPlaying = val.isPlaying;
    final isBuffering = val.isBuffering;
    final pos = val.position;
    final dur = val.duration;

    if (isPlaying && _hasError) {
      _hasError = false;
      _errorMessage = '';
      _retryCount = 0;
    }

    // Save resume position periodically for VOD
    if (!widget.media.isLive && pos.inSeconds > 5 && isPlaying) {
      widget.libraryRepository.saveResumePosition(widget.media.id, pos);
    }

    _safeSetState(() {
      _isPlaying = isPlaying;
      _isBuffering = isBuffering;
      _position = pos;
      _duration = dur;
    });
  }

  void _startBufferTimeoutMonitor() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted || _controller == null) {
        timer.cancel();
        return;
      }

      if (_isBuffering && !_isPlaying) {
        // If buffering too long on live stream, handle timeout
        // (P1 backoff logic will be refined in Etapa 2, P0 ensures safe lifecycle)
      }
    });
  }

  void _handlePlaybackError(String message) {
    if (_isDisposed || !mounted) return;

    _safeSetState(() {
      _hasError = true;
      _errorMessage = message;
      _isBuffering = false;
      _isPlaying = false;
    });

    if (_retryCount < _maxRetries) {
      _retryCount++;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: 2 * _retryCount), () {
        if (!_isDisposed && mounted) {
          _retryPlayback();
        }
      });
    }
  }

  Future<void> _retryPlayback() async {
    if (_isDisposed) return;
    await _teardownCurrentController();
    await _initPlayer();
  }

  Future<void> _teardownCurrentController() async {
    _cancelAllTimers();
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
    if (_isDisposed || _controller == null || widget.media.isLive) return;
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
    if (_isDisposed || _controller == null || widget.media.isLive) return;
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

  void _showAudioTrackSelector() async {
    if (_isDisposed || _controller == null) return;
    try {
      final tracks = await _controller!.getAudioTracks();
      if (_isDisposed || !mounted || tracks == null || tracks.isEmpty) return;

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
      if (_isDisposed || !mounted || subtitles == null || subtitles.isEmpty) return;

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
    _cancelAllTimers();

    if (_controller != null) {
      try {
        _controller!.removeListener(_onPlayerStateChanged);
        _controller!.stop();
      } catch (e) {
        debugPrint('[PlayerScreen] Safe catch on dispose stop: $e');
      }
      try {
        _controller!.dispose();
      } catch (e) {
        debugPrint('[PlayerScreen] Safe catch on controller dispose: $e');
      }
      _controller = null;
    }

    _restoreSystemUI();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // VLC Video Surface
          if (_controller != null)
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

          // Error Overlay
          if (_hasError)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        _retryCount = 0;
                        _retryPlayback();
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
            media: widget.media,
            isPlaying: _isPlaying,
            isBuffering: _isBuffering,
            position: _position,
            duration: _duration,
            currentAspect: _aspectRatio,
            onBack: () => Navigator.of(context).pop(),
            onPlayPause: _togglePlayPause,
            onRewind: () => _seekBy(const Duration(seconds: -10)),
            onForward: () => _seekBy(const Duration(seconds: 10)),
            onSeek: _onSeek,
            onToggleAspect: _toggleAspectRatio,
            onAudioTrack: _showAudioTrackSelector,
            onSubtitles: _showSubtitleSelector,
            onUserInteraction: _toggleOverlay,
          ),
        ],
      ),
    );
  }
}
