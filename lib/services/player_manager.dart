import 'package:flutter/foundation.dart';
import 'media3_player_engine.dart';
import 'vlc_player_engine.dart';
import 'player_engine.dart';

/// Coordinates the lifecycle of the currently selected PlayerEngine.
///
/// Stage 1 deliberately keeps VLC ownership in PlayerScreen. Media3 is the
/// first engine migrated behind this manager; later stages can register VLC,
/// MPV and Android-native engines without changing the screen lifecycle.
class PlayerManager {
  PlayerEngine? _activeEngine;
  bool _disposed = false;

  PlayerEngine? get activeEngine => _activeEngine;
  PlayerBackend? get activeBackend => _activeEngine?.backend;
  bool get isDisposed => _disposed;

  Future<PlayerEngine> initializeVlc(String streamUrl) async {
    _ensureUsable();
    await disposeActiveEngine();
    final engine = VlcPlayerEngine();
    try {
      await engine.initialize(streamUrl);
      if (_disposed) {
        await engine.dispose();
        throw StateError('PlayerManager has been disposed');
      }
      _activeEngine = engine;
      debugPrint('[PlayerManager] VLC engine initialized');
      return engine;
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
  }

  Future<PlayerEngine> initializeMedia3(String streamUrl) async {
    _ensureUsable();

    await disposeActiveEngine();

    final engine = Media3PlayerEngine();
    try {
      await engine.initialize(streamUrl);

      if (_disposed) {
        await engine.dispose();
        throw StateError('PlayerManager has been disposed');
      }

      _activeEngine = engine;
      debugPrint('[PlayerManager] Media3 engine initialized');
      return engine;
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
  }

  Future<void> play() async {
    await _requireActiveEngine().play();
  }

  Future<void> pause() async {
    await _requireActiveEngine().pause();
  }

  Future<void> stop() async {
    await _requireActiveEngine().stop();
  }

  Future<void> seekTo(Duration position) async {
    await _requireActiveEngine().seekTo(position);
  }

  Future<void> setVolume(double volume) async {
    await _requireActiveEngine().setVolume(volume);
  }

  Future<void> disposeActiveEngine() async {
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
  }

  PlayerEngine _requireActiveEngine() {
    _ensureUsable();
    final engine = _activeEngine;
    if (engine == null) {
      throw StateError('No active player engine');
    }
    return engine;
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('PlayerManager has already been disposed');
    }
  }
}
