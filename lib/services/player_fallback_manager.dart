import 'player_engine.dart';

enum PlayerErrorKind {
  network,
  timeout,
  decoder,
  unsupported,
  initialization,
  unknown,
}

enum PlayerFallbackDecision {
  retryCurrent,
  switchBackend,
  failed,
}

class PlayerFallbackManager {
  final List<PlayerBackend> backendOrder;

  final Set<PlayerBackend> _attemptedBackends = <PlayerBackend>{};
  int _generation = 0;
  bool _disposed = false;

  PlayerFallbackManager({
    List<PlayerBackend>? backendOrder,
  }) : backendOrder = List.unmodifiable(
          backendOrder ?? const [PlayerBackend.vlc, PlayerBackend.media3],
        );

  int get generation => _generation;
  bool get isDisposed => _disposed;
  Set<PlayerBackend> get attemptedBackends =>
      Set.unmodifiable(_attemptedBackends);

  void startSession() {
    _ensureUsable();
    _generation++;
    _attemptedBackends.clear();
  }

  void markAttempt(PlayerBackend backend) {
    _ensureUsable();
    _attemptedBackends.add(backend);
  }

  bool isAttempted(PlayerBackend backend) => _attemptedBackends.contains(backend);

  PlayerBackend? nextBackend({PlayerBackend? current}) {
    _ensureUsable();
    for (final backend in backendOrder) {
      if (_attemptedBackends.contains(backend)) continue;
      if (current != null && backend == current) continue;
      return backend;
    }
    return null;
  }

  PlayerFallbackDecision decide({
    required PlayerBackend current,
    required Object error,
    bool isLive = false,
  }) {
    _ensureUsable();
    final kind = classifyError(error);

    if (nextBackend(current: current) != null &&
        (kind == PlayerErrorKind.decoder ||
            kind == PlayerErrorKind.unsupported ||
            kind == PlayerErrorKind.initialization)) {
      return PlayerFallbackDecision.switchBackend;
    }

    if (isLive && nextBackend(current: current) != null &&
        (kind == PlayerErrorKind.network ||
            kind == PlayerErrorKind.timeout)) {
      return PlayerFallbackDecision.switchBackend;
    }

    if (kind == PlayerErrorKind.network || kind == PlayerErrorKind.timeout) {
      return PlayerFallbackDecision.retryCurrent;
    }

    return nextBackend(current: current) != null
        ? PlayerFallbackDecision.switchBackend
        : PlayerFallbackDecision.failed;
  }

  static PlayerErrorKind classifyError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('deadline')) {
      return PlayerErrorKind.timeout;
    }

    if (message.contains('decoder') ||
        message.contains('codec') ||
        message.contains('decode') ||
        message.contains('format') ||
        message.contains('source error') ||
        message.contains('unsupported')) {
      return PlayerErrorKind.decoder;
    }

    if (message.contains('initialize') ||
        message.contains('initializ') ||
        message.contains('controller')) {
      return PlayerErrorKind.initialization;
    }

    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('clientconnection') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('http') ||
        message.contains('404') ||
        message.contains('500')) {
      return PlayerErrorKind.network;
    }

    return PlayerErrorKind.unknown;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _attemptedBackends.clear();
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('PlayerFallbackManager has already been disposed');
    }
  }
}
