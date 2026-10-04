import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/player_engine.dart';
import 'package:best_player/services/player_fallback_manager.dart';

void main() {
  group('PlayerFallbackManager', () {
    test('inicia uma sessão nova e limpa backends anteriores', () {
      final manager = PlayerFallbackManager();

      manager.startSession();
      expect(manager.backendOrder.first, equals(PlayerBackend.media3));
      manager.markAttempt(PlayerBackend.media3);
      expect(manager.nextBackend(current: PlayerBackend.media3),
          equals(PlayerBackend.vlc));

      manager.startSession();
      expect(manager.attemptedBackends, isEmpty);
      expect(manager.generation, equals(2));
      manager.dispose();
    });

    test('não entra em loop: cada backend é tentado uma vez por sessão', () {
      final manager = PlayerFallbackManager();
      manager.startSession();

      manager.markAttempt(PlayerBackend.media3);
      expect(manager.nextBackend(current: PlayerBackend.media3),
          equals(PlayerBackend.vlc));

      manager.markAttempt(PlayerBackend.vlc);
      expect(manager.nextBackend(current: PlayerBackend.media3), isNull);
      manager.dispose();
    });

    test('classifica erros de conexão, timeout e decoder', () {
      expect(
        PlayerFallbackManager.classifyError(
          'ClientConnection closed while receiving data',
        ),
        equals(PlayerErrorKind.network),
      );
      expect(
        PlayerFallbackManager.classifyError('Socket timeout after 60 seconds'),
        equals(PlayerErrorKind.timeout),
      );
      expect(
        PlayerFallbackManager.classifyError('Decoder initialization failed'),
        equals(PlayerErrorKind.decoder),
      );
      expect(
        PlayerFallbackManager.classifyError('unsupported video format'),
        equals(PlayerErrorKind.decoder),
      );
    });

    test('erro de decoder favorece troca de backend', () {
      final manager = PlayerFallbackManager();
      manager.startSession();
      manager.markAttempt(PlayerBackend.vlc);

      expect(
        manager.decide(
          current: PlayerBackend.vlc,
          error: 'decoder failed for HLS stream',
        ),
        equals(PlayerFallbackDecision.switchBackend),
      );
      manager.dispose();
    });

    test('erro de rede em VOD prefere retry do backend atual', () {
      final manager = PlayerFallbackManager();
      manager.startSession();
      manager.markAttempt(PlayerBackend.vlc);

      expect(
        manager.decide(
          current: PlayerBackend.vlc,
          error: 'connection reset by peer',
          isLive: false,
        ),
        equals(PlayerFallbackDecision.retryCurrent),
      );
      manager.dispose();
    });

    test('erro de rede em LIVE permite failover para outro backend', () {
      final manager = PlayerFallbackManager();
      manager.startSession();
      manager.markAttempt(PlayerBackend.vlc);

      expect(
        manager.decide(
          current: PlayerBackend.vlc,
          error: 'network connection closed',
          isLive: true,
        ),
        equals(PlayerFallbackDecision.switchBackend),
      );
      manager.dispose();
    });

    test('sem backend alternativo retorna failed', () {
      final manager = PlayerFallbackManager();
      manager.startSession();
      manager.markAttempt(PlayerBackend.vlc);
      manager.markAttempt(PlayerBackend.media3);

      expect(
        manager.decide(
          current: PlayerBackend.media3,
          error: 'decoder failed',
        ),
        equals(PlayerFallbackDecision.failed),
      );
      manager.dispose();
    });

    test('dispose invalida a sessão e impede novas operações', () {
      final manager = PlayerFallbackManager();
      manager.startSession();
      final generation = manager.generation;

      manager.dispose();

      expect(manager.isDisposed, isTrue);
      expect(manager.generation, equals(generation + 1));
      expect(
        () => manager.startSession(),
        throwsStateError,
      );
    });
  });
}
