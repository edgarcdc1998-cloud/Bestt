import 'package:video_player/video_player.dart';
import 'player_engine.dart';

/// Media3/ExoPlayer-backed engine through Flutter's Android video_player
/// implementation.
///
/// This is deliberately independent from PlayerScreen in this stage.
/// VLC remains the active production player until A/B validation is complete.
class Media3PlayerEngine implements PlayerEngine {
  VideoPlayerController? _controller;
  bool _disposed = false;

  @override
  PlayerBackend get backend => PlayerBackend.media3;

  @override
  VideoPlayerController? get videoController => _controller;

  @override
  Future<void> initialize(String streamUrl) async {
    if (_disposed) {
      throw StateError('Media3PlayerEngine has already been disposed');
    }
    if (streamUrl.trim().isEmpty) {
      throw ArgumentError.value(streamUrl, 'streamUrl', 'Stream URL cannot be empty');
    }

    await _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));

    try {
      await _controller!.initialize();
    } catch (_) {
      await _controller?.dispose();
      _controller = null;
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    final controller = _requireController();
    await controller.play();
  }

  @override
  Future<void> pause() async {
    final controller = _requireController();
    await controller.pause();
  }

  @override
  Future<void> stop() async {
    final controller = _requireController();
    await controller.pause();
    await controller.seekTo(Duration.zero);
  }

  @override
  Future<void> seekTo(Duration position) async {
    final controller = _requireController();
    await controller.seekTo(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    final controller = _requireController();
    await controller.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  VideoPlayerController _requireController() {
    if (_disposed) {
      throw StateError('Media3PlayerEngine has already been disposed');
    }

    final controller = _controller;
    if (controller == null) {
      throw StateError('Media3PlayerEngine is not initialized');
    }

    return controller;
  }
}
