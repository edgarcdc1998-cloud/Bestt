import 'dart:async';

import 'package:flutter_vlc_player_16kb/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';

import 'player_engine.dart';

class VlcPlayerEngine implements PlayerEngine {
  VlcPlayerController? _controller;
  final StreamController<PlayerEngineState> _stateController =
      StreamController<PlayerEngineState>.broadcast();
  PlayerEngineState _state = PlayerEngineState.idle;
  Object? _lastError;
  bool _disposed = false;

  @override
  PlayerBackend get backend => PlayerBackend.vlc;

  VlcPlayerController? get controller => _controller;

  @override
  VideoPlayerController? get videoController => null;

  @override
  PlayerEngineState get state => _state;

  @override
  Stream<PlayerEngineState> get stateStream => _stateController.stream;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  Object? get lastError => _lastError;

  @override
  Future<void> initialize(String streamUrl) async {
    if (_disposed) throw StateError('VlcPlayerEngine has already been disposed');
    if (streamUrl.trim().isEmpty) {
      throw ArgumentError.value(streamUrl, 'streamUrl', 'Stream URL cannot be empty');
    }

    _setState(PlayerEngineState.initializing);
    _lastError = null;

    final controller = VlcPlayerController.network(
      streamUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          '--network-caching=1500',
          '--live-caching=1500',
        ]),
        http: VlcHttpOptions(['--http-reconnect']),
        rtp: VlcRtpOptions(['--rtsp-tcp']),
      ),
    );

    _controller = controller;
    controller.addListener(_onControllerChanged);

    try {
      _onControllerChanged();
    } catch (error) {
      _lastError = error;
      controller.removeListener(_onControllerChanged);
      await controller.dispose();
      _controller = null;
      _setState(PlayerEngineState.failed);
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    await _requireController().play();
    _onControllerChanged();
  }

  @override
  Future<void> pause() async {
    await _requireController().pause();
    _onControllerChanged();
  }

  @override
  Future<void> stop() async {
    final controller = _requireController();
    await controller.stop();
    _setState(PlayerEngineState.stopped);
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _requireController().seekTo(position);
    _onControllerChanged();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _requireController().setVolume(
      (volume.clamp(0.0, 1.0) * 100).round(),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    await controller?.stop().catchError((_) {});
    await controller?.dispose();
    _setState(PlayerEngineState.disposed);
    await _stateController.close();
  }

  VlcPlayerController _requireController() {
    if (_disposed) throw StateError('VlcPlayerEngine has already been disposed');
    final controller = _controller;
    if (controller == null) throw StateError('VlcPlayerEngine is not initialized');
    return controller;
  }

  void _onControllerChanged() {
    if (_disposed || _controller == null) return;
    final value = _controller!.value;
    if (value.hasError) {
      _lastError = value.errorDescription;
      _setState(PlayerEngineState.failed);
      return;
    }
    if (!value.isInitialized) return;
    if (value.isBuffering) {
      _setState(PlayerEngineState.buffering);
    } else if (value.isPlaying) {
      _setState(PlayerEngineState.playing);
    } else if (_state != PlayerEngineState.stopped) {
      _setState(PlayerEngineState.paused);
    }
  }

  void _setState(PlayerEngineState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}
