import 'package:video_player/video_player.dart';

enum PlayerBackend {
  vlc,
  media3,
}

/// Common lifecycle contract for alternative playback engines.
///
/// The interface intentionally does not expose UI concerns. This lets the
/// existing VLC implementation and the Media3 implementation be tested
/// independently before PlayerScreen is switched to either backend.
abstract interface class PlayerEngine {
  PlayerBackend get backend;

  VideoPlayerController? get videoController;

  Future<void> initialize(String streamUrl);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seekTo(Duration position);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}
