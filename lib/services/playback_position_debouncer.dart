import 'dart:async';
import 'package:flutter/foundation.dart';

typedef PositionPersistCallback = Future<void> Function(Map<String, Duration> positions);

class PlaybackPositionDebouncer {
  final Duration interval;
  final PositionPersistCallback onPersist;

  Timer? _debounceTimer;
  bool _hasPendingWrite = false;
  Future<void>? _activePersistFuture;
  bool _isDisposed = false;

  PlaybackPositionDebouncer({
    this.interval = const Duration(seconds: 3),
    required this.onPersist,
  });

  bool get hasPendingWrite => _hasPendingWrite;
  bool get isPersisting => _activePersistFuture != null;
  bool get isDisposed => _isDisposed;

  /// Validates if a playback position is structurally sound.
  static bool isValidPosition(Duration? position) {
    if (position == null) return false;
    if (position.isNegative) return false;
    // Preserves original project rule: discard positions < 5s
    if (position.inSeconds < 5) return false;
    // Guard against corrupted / overflow values (> 100 hours)
    if (position.inHours > 100) return false;
    return true;
  }

  /// Registers a position update in memory and schedules a debounced write.
  void recordPosition(
    String mediaId,
    Duration position,
    Map<String, Duration> inMemoryMap,
  ) {
    if (_isDisposed) return;
    if (mediaId.trim().isEmpty) return;
    if (!isValidPosition(position)) return;

    // 1. Immediate in-memory cache update for instant synchronous retrieval
    inMemoryMap[mediaId] = position;
    _hasPendingWrite = true;

    // 2. Reset and schedule debounced persistent write
    _debounceTimer?.cancel();
    _debounceTimer = Timer(interval, () async {
      if (!_isDisposed && _hasPendingWrite) {
        await _executePersistLoop(inMemoryMap);
      }
    });
  }

  /// Forces immediate persistence of any pending positions.
  /// If a persistence is currently in flight, awaits it and persists any new pending updates.
  Future<void> flush(Map<String, Duration> inMemoryMap) async {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_activePersistFuture != null) {
      await _activePersistFuture;
    }

    if (_hasPendingWrite && !_isDisposed) {
      await _executePersistLoop(inMemoryMap);
    }
  }

  /// Concurrency-safe execution loop: continuously drains pending writes until clean.
  Future<void> _executePersistLoop(Map<String, Duration> inMemoryMap) async {
    if (_activePersistFuture != null) {
      // Already running, the existing loop will pick up _hasPendingWrite
      return;
    }

    final completer = Completer<void>();
    _activePersistFuture = completer.future;

    try {
      while (_hasPendingWrite && !_isDisposed) {
        _hasPendingWrite = false;
        final snapshot = Map<String, Duration>.from(inMemoryMap);
        await onPersist(snapshot);
      }
    } catch (e, stack) {
      debugPrint('[PlaybackPositionDebouncer] Error persisting playback positions: $e\n$stack');
    } finally {
      _activePersistFuture = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  /// Cancels scheduled debounced writes.
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _hasPendingWrite = false;
  }

  /// Disposes the debouncer safely and flushes any pending write.
  Future<void> dispose(Map<String, Duration> inMemoryMap) async {
    if (_isDisposed) return;
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_activePersistFuture != null) {
      await _activePersistFuture;
    }

    if (_hasPendingWrite) {
      try {
        final snapshot = Map<String, Duration>.from(inMemoryMap);
        _hasPendingWrite = false;
        await onPersist(snapshot);
      } catch (e) {
        debugPrint('[PlaybackPositionDebouncer] Error during dispose flush: $e');
      }
    }
  }
}
