import 'dart:async';
import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  failed,
  disposed,
}

typedef ConnectionCallback = Future<void> Function(int generationId);

class PlayerConnectionManager {
  final int maxRetries;
  final Duration baseBackoff;

  ConnectionStatus _status = ConnectionStatus.idle;
  String _errorMessage = '';
  int _currentGeneration = 0;
  int _retryCount = 0;
  bool _isDisposed = false;
  bool _isConnecting = false;

  Timer? _reconnectTimer;
  Timer? _bufferTimer;
  ConnectionCallback? _connectCallback;

  // Listeners for UI state updates
  final List<VoidCallback> _listeners = [];

  PlayerConnectionManager({
    this.maxRetries = 3,
    this.baseBackoff = const Duration(seconds: 2),
  });

  ConnectionStatus get status => _status;
  String get errorMessage => _errorMessage;
  int get currentGeneration => _currentGeneration;
  int get retryCount => _retryCount;
  bool get isDisposed => _isDisposed;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isFailed => _status == ConnectionStatus.failed;
  bool get isReconnecting => _status == ConnectionStatus.reconnecting;

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    if (_isDisposed) return;
    for (final listener in List<VoidCallback>.from(_listeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('[PlayerConnectionManager] Listener error: $e');
      }
    }
  }

  void _setStatus(ConnectionStatus newStatus, {String errorMessage = ''}) {
    if (_isDisposed) return;
    _status = newStatus;
    _errorMessage = errorMessage;
    _notifyListeners();
  }

  /// Cancels all active timers without changing generation.
  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _bufferTimer?.cancel();
    _bufferTimer = null;
  }

  /// Starts a new connection for a stream.
  /// Automatically invalidates any previous generation and cancels pending retries/timers.
  Future<void> connect(ConnectionCallback connectCallback) async {
    if (_isDisposed) return;

    // Invalidate previous generation & cancel timers
    _currentGeneration++;
    final generation = _currentGeneration;
    _cancelTimers();
    _isConnecting = false;

    _connectCallback = connectCallback;
    _retryCount = 0;
    _setStatus(ConnectionStatus.connecting);

    await _executeConnect(generation);
  }

  /// Internal connection execution guarded by generation check and concurrency lock.
  Future<void> _executeConnect(int generation) async {
    if (_isDisposed || generation != _currentGeneration) return;

    // Prevent concurrent executions for the same generation
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      if (_connectCallback != null) {
        await _connectCallback!(generation);
      }
      
      // Verify generation again after async operation completes
      if (_isDisposed || generation != _currentGeneration) return;

      _isConnecting = false;
      _retryCount = 0;
      // The attempt itself does not mean playback is connected.
      // onStreamConnected() is the authoritative transition.
    } catch (e) {
      if (_isDisposed || generation != _currentGeneration) return;
      _isConnecting = false;
      _handleFailure(generation, e.toString());
    }
  }

  /// Handles connection failure with bounded backoff retry.
  void _handleFailure(int generation, String error) {
    if (_isDisposed || generation != _currentGeneration) return;

    _cancelTimers();

    if (_retryCount < maxRetries) {
      _retryCount++;
      _setStatus(
        ConnectionStatus.reconnecting,
        errorMessage: 'Tentativa $_retryCount de $maxRetries: $error',
      );

      final delayDuration = baseBackoff * _retryCount;
      _reconnectTimer = Timer(delayDuration, () async {
        if (!_isDisposed && generation == _currentGeneration) {
          await _executeConnect(generation);
        }
      });
    } else {
      _setStatus(
        ConnectionStatus.failed,
        errorMessage: 'Falha na reprodução após $maxRetries tentativas: $error',
      );
    }
  }

  /// Called by the player when a stream error occurs.
  void onStreamError(String error) {
    if (_isDisposed || _status == ConnectionStatus.failed) return;

    final generation = _currentGeneration;
    _handleFailure(generation, error);
  }

  /// Called when stream reports connected/playing.
  void onStreamConnected() {
    if (_isDisposed || _status == ConnectionStatus.connected) return;

    _cancelTimers();
    _isConnecting = false;
    _retryCount = 0;
    _setStatus(ConnectionStatus.connected);
  }

  /// Called when buffering starts or stops.
  /// If buffering is prolonged (e.g. timeout), triggers reconnection safely without race conditions.
  void onBufferingState(bool isBuffering, {Duration timeout = const Duration(seconds: 10)}) {
    if (_isDisposed) return;

    if (!isBuffering) {
      _bufferTimer?.cancel();
      _bufferTimer = null;
      return;
    }

    // If already buffering monitor is active or reconnecting, do not duplicate
    if (_bufferTimer != null || _status == ConnectionStatus.reconnecting || _status == ConnectionStatus.connecting) {
      return;
    }

    final generation = _currentGeneration;
    _bufferTimer = Timer(timeout, () {
      if (!_isDisposed && generation == _currentGeneration && _status == ConnectionStatus.connected) {
        _handleFailure(generation, 'Tempo limite de buffer excedido');
      }
    });
  }

  /// Manual retry triggered by the user in UI.
  /// Cancels any scheduled automatic retry and immediately re-executes for current generation.
  Future<void> retryManual() async {
    if (_isDisposed) return;

    // Manual retry starts a new generation and invalidates any late result.
    _currentGeneration++;
    final generation = _currentGeneration;
    _cancelTimers();
    _isConnecting = false;
    _retryCount = 0;
    _setStatus(ConnectionStatus.connecting);

    await _executeConnect(generation);
  }

  /// Cancels current connection and invalidates generation.
  void cancel() {
    if (_isDisposed) return;
    _currentGeneration++;
    _cancelTimers();
    _isConnecting = false;
    _setStatus(ConnectionStatus.idle);
  }

  /// Disposes the manager and releases all listeners and timers.
  void dispose() {
    _isDisposed = true;
    _currentGeneration++;
    _cancelTimers();
    _isConnecting = false;
    _connectCallback = null;
    _status = ConnectionStatus.disposed;
    _listeners.clear();
  }
}
