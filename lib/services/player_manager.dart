import 'dart:async';
import 'package:flutter/foundation.dart';
import 'media3_player_engine.dart';
import 'player_connection_manager.dart';
import 'player_engine.dart';
import 'player_fallback_manager.dart';
import 'vlc_player_engine.dart';

class PlayerManager {
  PlayerEngine? _activeEngine;
  PlayerConnectionManager? _connectionManager;
  StreamSubscription<PlayerEngineState>? _engineStateSubscription;
  bool _disposed = false;
  final PlayerFallbackManager _fallbackManager = PlayerFallbackManager();
  PlayerBackend? _lastBackend;

  PlayerEngine? get activeEngine => _activeEngine;
  PlayerBackend? get activeBackend => _activeEngine?.backend;
  PlayerEngineState? get state => _activeEngine?.state;
  bool get isDisposed => _disposed;
  PlayerFallbackManager get fallbackManager => _fallbackManager;

  void startPlaybackSession() {
    _ensureUsable();
    _fallbackManager.startSession();
    _lastBackend = null;
  }

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
      _initializeBackend(PlayerBackend.vlc, streamUrl);

  Future<PlayerEngine> initializeMedia3(String streamUrl) async =>
      _initializeBackend(PlayerBackend.media3, streamUrl);

  Future<PlayerEngine> initializeWithFallback(String streamUrl) async {
    _ensureUsable();
    final candidates = <PlayerBackend>[];
    final next = _fallbackManager.nextBackend();
    if (next != null) candidates.add(next);
    if (_lastBackend != null && !candidates.contains(_lastBackend)) candidates.add(_lastBackend!);
    for (final backend in _fallbackManager.backendOrder) {
      if (!candidates.contains(backend) &&
          (!_fallbackManager.isAttempted(backend) || _lastBackend == backend)) {
        candidates.add(backend);
      }
    }
    Object? lastError;
    for (final backend in candidates) {
      try {
        return await _initializeBackend(backend, streamUrl);
      } catch (error) {
        lastError = error;
        debugPrint('[PlayerManager] backend initialization failed: $error');
      }
    }
    throw StateError('Todos os backends de player falharam: $lastError');
  }

  Future<PlayerEngine> _initializeBackend(PlayerBackend backend, String streamUrl) async {
    final engine = backend == PlayerBackend.vlc ? VlcPlayerEngine() : Media3PlayerEngine();
    final label = backend == PlayerBackend.vlc ? 'VLC' : 'Media3';
    _fallbackManager.markAttempt(backend);
    final result = await _initialize(engine, streamUrl, label);
    _lastBackend = backend;
    return result;
  }
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
    _fallbackManager.dispose();
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
