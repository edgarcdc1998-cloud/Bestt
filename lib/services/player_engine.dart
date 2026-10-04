import 'dart:async';

import 'package:video_player/video_player.dart';

enum PlayerBackend {
  vlc,
  media3,
}

enum PlayerEngineState {
  idle,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  stopped,
  failed,
  disposed,
}

abstract interface class PlayerEngine {
  PlayerBackend get backend;
  VideoPlayerController? get videoController;
  PlayerEngineState get state;
  Stream<PlayerEngineState> get stateStream;
  Duration get position;
  Duration get duration;
  bool get isPlaying;
  Object? get lastError;

  Future<void> initialize(String streamUrl);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}
