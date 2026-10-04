import 'dart:async';
import 'package:flutter/foundation.dart';
import 'media3_player_engine.dart';
import 'player_connection_manager.dart';
import 'player_engine.dart';
import 'vlc_player_engine.dart';

class PlayerManager {
  PlayerEngine? _activeEngine;
  PlayerConnectionManager? _connectionManager;
  StreamSubscription<PlayerEngineState>? _engineStateSubscription;
  bool _disposed = false;

  PlayerEngine? get activeEngine => _activeEngine;
  PlayerBackend? get activeBackend => _activeEngine?.backend;
  PlayerEngineState? get state => _activeEngine?.state;
  bool get isDisposed => _disposed;

  void bindConnectionManager(PlayerConnectionManager manager) {
    _ensureUsable();
    if (identical(_connectionManager, manager)) return;
    _engineStateSubscription?.cancel();
    _engineStateSubscription = null;
    _connectionManager = manager;
    final engine = _activeEngine;
    if (engine != null) _listenToEngine(engine);
  }

  Future<PlayerEngine> initializeVlc(String streamUrl) async =>
      _initialize(VlcPlayerEngine(), streamUrl, 'VLC');

  Future<PlayerEngine> initializeMedia3(String streamUrl) async =>
      _initialize(Media3PlayerEngine(), streamUrl, 'Media3');

  Future<PlayerEngine> _initialize(PlayerEngine engine, String streamUrl, String label) async {
    _ensureUsable();
    await disposeActiveEngine();
    try {
      await engine.initialize(streamUrl);
      if (_disposed) {
        await engine.dispose();
        throw StateError('PlayerManager has been disposed');
      }
      _activeEngine = engine;
      _listenToEngine(engine);
      debugPrint('[PlayerManager] $label engine initialized');
      return engine;
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
  }

  void _listenToEngine(PlayerEngine engine) {
    _engineStateSubscription?.cancel();
    _engineStateSubscription = engine.stateStream.listen(
      (state) => _onEngineState(engine, state),
      onError: (Object error, StackTrace stack) {
        _connectionManager?.onStreamError(error.toString());
      },
    );
    _onEngineState(engine, engine.state);
  }

  void _onEngineState(PlayerEngine engine, PlayerEngineState state) {
    if (_disposed || !identical(engine, _activeEngine)) return;
    final connection = _connectionManager;
    if (connection == null) return;

    switch (state) {
      case PlayerEngineState.playing:
        connection.onStreamConnected();
        connection.onBufferingState(false);
        break;
      case PlayerEngineState.buffering:
        connection.onBufferingState(true);
        break;
      case PlayerEngineState.failed:
        connection.onStreamError(
          engine.lastError?.toString() ?? 'Falha no player ${engine.backend.name}',
        );
        break;
      case PlayerEngineState.disposed:
      case PlayerEngineState.idle:
      case PlayerEngineState.initializing:
      case PlayerEngineState.ready:
      case PlayerEngineState.paused:
      case PlayerEngineState.stopped:
        break;
    }
  }

  Future<void> play() async => _requireActiveEngine().play();
  Future<void> pause() async => _requireActiveEngine().pause();
  Future<void> stop() async => _requireActiveEngine().stop();
  Future<void> seekTo(Duration position) async => _requireActiveEngine().seekTo(position);
  Future<void> setVolume(double volume) async => _requireActiveEngine().setVolume(volume);

  Future<void> disposeActiveEngine() async {
    await _engineStateSubscription?.cancel();
    _engineStateSubscription = null;
    final engine = _activeEngine;
    _activeEngine = null;
    if (engine != null) {
      try {
        await engine.dispose();
      } catch (error) {
        debugPrint('[PlayerManager] Engine dispose error: $error');
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disposeActiveEngine();
    _connectionManager = null;
  }

  PlayerEngine _requireActiveEngine() {
    _ensureUsable();
    final engine = _activeEngine;
    if (engine == null) throw StateError('No active player engine');
    return engine;
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('PlayerManager has already been disposed');
  }
}
