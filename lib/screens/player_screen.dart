import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/media_item.dart';
import '../repositories/library_repository.dart';
import '../services/player_connection_manager.dart';
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
  late final PlayerConnectionManager _connectionManager;
  VlcPlayerController? _controller;
  bool _isDisposed = false;
  bool _isOverlayVisible = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _aspectRatio = '16:9';

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
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

      final resumePos = widget.libraryRepository.getResumePosition(widget.media.id);

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

      if (_isDisposed || generation != _connectionManager.currentGeneration) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      _controller = controller;
      _controller!.addListener(_onPlayerStateChanged);

      _safeSetState(() {
        _isBuffering = true;
      });

      // Resume playback position for movies/series
      if (resumePos != null && !widget.media.isLive && resumePos.inSeconds > 0) {
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
      widget.libraryRepository.addToHistory(widget.media);
    });
  }

  void _onPlayerStateChanged() {
    if (_isDisposed || !mounted || _controller == null) return;

    final val = _controller!.value;

    if (val.hasError) {
      final desc = val.errorDescription.isNotEmpty ? val.errorDescription : 'Erro na reprodução do fluxo';
      _connectionManager.onStreamError(desc);
      return;
    }

    final isPlaying = val.isPlaying;
    final isBuffering = val.isBuffering;
    final pos = val.position;
    final dur = val.duration;

    if (isPlaying) {
      _connectionManager.onStreamConnected();
    }

    _connectionManager.onBufferingState(isBuffering);

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
    _hideTimer?.cancel();
    _hideTimer = null;

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
      body: Stack(
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
            media: widget.media,
            isPlaying: _isPlaying,
            isBuffering: _isBuffering || isReconnecting,
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
