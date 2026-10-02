import 'dart:async';
import 'package:flutter/foundation.dart';

typedef PositionPersistCallback = Future<void> Function(Map<String, Duration> positions);

class PlaybackPositionDebouncer {
  final Duration interval;
  final PositionPersistCallback onPersist;

  Timer? _debounceTimer;
  bool _hasPendingWrite = false;
  bool _isPersisting = false;
  bool _isDisposed = false;

  PlaybackPositionDebouncer({
    this.interval = const Duration(seconds: 3),
    required this.onPersist,
  });

  bool get hasPendingWrite => _hasPendingWrite;
  bool get isPersisting => _isPersisting;
  bool get isDisposed => _isDisposed;

  /// Validates if a playback position is structurally sound.
  static bool isValidPosition(Duration? position) {
    if (position == null) return false;
    if (position.isNegative) return false;
    // Discard positions less than 5 seconds (start of video) or absurd values (> 100 hours)
    if (position.inSeconds < 5) return false;
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
        await _executePersist(inMemoryMap);
      }
    });
  }

  /// Forces immediate asynchronous persistence of any pending positions.
  Future<void> flush(Map<String, Duration> inMemoryMap) async {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (_hasPendingWrite) {
      await _executePersist(inMemoryMap);
    }
  }

  /// Internal persistence execution with concurrency guard.
  Future<void> _executePersist(Map<String, Duration> inMemoryMap) async {
    if (_isPersisting || _isDisposed) return;
    _isPersisting = true;

    try {
      // Capture a snapshot of current in-memory positions
      final snapshot = Map<String, Duration>.from(inMemoryMap);
      _hasPendingWrite = false;
      await onPersist(snapshot);
    } catch (e, stack) {
      debugPrint('[PlaybackPositionDebouncer] Error persisting playback positions: $e\n$stack');
    } finally {
      _isPersisting = false;
    }
  }

  /// Cancels scheduled debounced writes.
  void cancel() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _hasPendingWrite = false;
  }

  /// Disposes the debouncer safely.
  Future<void> dispose(Map<String, Duration> inMemoryMap) async {
    if (_isDisposed) return;
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

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
