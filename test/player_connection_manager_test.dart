import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/player_connection_manager.dart';

void main() {
  group('PlayerConnectionManager Tests', () {
    test('Teste 1: Conexão bem-sucedida', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      bool connectedCalled = false;
      await manager.connect((gen) async {
        connectedCalled = true;
      });

      expect(connectedCalled, isTrue);
      expect(manager.status, equals(ConnectionStatus.connected));
      expect(manager.isConnected, isTrue);
      expect(manager.retryCount, equals(0));

      manager.dispose();
    });

    test('Teste 2: Primeira tentativa falha e retry funciona', () async {
      final manager = PlayerConnectionManager(
        maxRetries: 2,
        baseBackoff: const Duration(milliseconds: 20),
      );

      int attempts = 0;
      await manager.connect((gen) async {
        attempts++;
        if (attempts == 1) {
          throw Exception('Network timeout');
        }
      });

      expect(attempts, equals(1));
      expect(manager.status, equals(ConnectionStatus.reconnecting));
      expect(manager.retryCount, equals(1));

      // Wait for the scheduled backoff retry to execute
      await Future.delayed(const Duration(milliseconds: 60));

      expect(attempts, equals(2));
      expect(manager.status, equals(ConnectionStatus.connected));

      manager.dispose();
    });

    test('Teste 3: Número máximo de retries é respeitado', () async {
      final manager = PlayerConnectionManager(
        maxRetries: 2,
        baseBackoff: const Duration(milliseconds: 10),
      );

      int attempts = 0;
      await manager.connect((gen) async {
        attempts++;
        throw Exception('Persistent 404 stream error');
      });

      // Wait for all retries to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(attempts, equals(3)); // Initial attempt (1) + 2 retries
      expect(manager.status, equals(ConnectionStatus.failed));
      expect(manager.isFailed, isTrue);

      manager.dispose();
    });

    test('Teste 4: Duas chamadas simultâneas de connect não criam operações concorrentes na mesma geração', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      int executionCount = 0;
      final completer = Completer<void>();

      // Connect call 1
      manager.connect((gen) async {
        executionCount++;
        await completer.future;
      });

      // Wait a tick, then try to trigger another stream error / connect during execution
      manager.onStreamError('Stream dropped while connecting');

      completer.complete();
      await Future.delayed(const Duration(milliseconds: 30));

      expect(executionCount, equals(1));

      manager.dispose();
    });

    test('Teste 5: Conexão antiga (geração defasada) não sobrescreve conexão nova', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      final slowCompleter = Completer<void>();
      int firstGenId = 0;

      // Start Connection A (generation 1)
      unawaited(manager.connect((gen) async {
        firstGenId = gen;
        await slowCompleter.future;
      }));

      expect(manager.currentGeneration, equals(1));

      // Immediately switch channel / start Connection B (generation 2)
      bool connectionBSucceeded = false;
      await manager.connect((gen) async {
        connectionBSucceeded = true;
      });

      expect(manager.currentGeneration, equals(2));
      expect(manager.status, equals(ConnectionStatus.connected));

      // Now complete the slow Connection A from generation 1
      slowCompleter.complete();
      await Future.delayed(const Duration(milliseconds: 20));

      // Status must still reflect Connection B (connected, generation 2)
      expect(manager.currentGeneration, equals(2));
      expect(manager.status, equals(ConnectionStatus.connected));
      expect(connectionBSucceeded, isTrue);

      manager.dispose();
    });

    test('Teste 6: Cancelamento invalida a operação', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      final completer = Completer<void>();
      unawaited(manager.connect((gen) async {
        await completer.future;
      }));

      expect(manager.status, equals(ConnectionStatus.connecting));

      manager.cancel();

      expect(manager.status, equals(ConnectionStatus.idle));
      expect(manager.isConnecting, isFalse);

      // Late completion of canceled task
      completer.complete();
      await Future.delayed(const Duration(milliseconds: 20));

      expect(manager.status, equals(ConnectionStatus.idle));

      manager.dispose();
    });

    test('Teste 7: Depois de dispose, nenhuma operação pode modificar o estado', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      await manager.connect((gen) async {});
      expect(manager.status, equals(ConnectionStatus.connected));

      manager.dispose();
      expect(manager.status, equals(ConnectionStatus.disposed));

      // Attempting operations post-dispose
      await manager.connect((gen) async {});
      manager.onStreamError('Late error');
      manager.onBufferingState(true);
      await manager.retryManual();

      expect(manager.status, equals(ConnectionStatus.disposed));
    });

    test('Teste 8: Timer de retry é cancelado corretamente no cancelamento ou novo connect', () async {
      final manager = PlayerConnectionManager(
        maxRetries: 3,
        baseBackoff: const Duration(milliseconds: 50),
      );

      int attempts = 0;
      await manager.connect((gen) async {
        attempts++;
        throw Exception('First failure');
      });

      expect(manager.status, equals(ConnectionStatus.reconnecting));
      expect(attempts, equals(1));

      // Cancel before the 50ms timer fires
      manager.cancel();
      expect(manager.status, equals(ConnectionStatus.idle));

      // Wait past the timer duration
      await Future.delayed(const Duration(milliseconds: 80));

      // No retry should have been executed
      expect(attempts, equals(1));
      expect(manager.status, equals(ConnectionStatus.idle));

      manager.dispose();
    });

    test('Teste 9: Buffering não cria retries duplicados', () async {
      final manager = PlayerConnectionManager(
        baseBackoff: const Duration(milliseconds: 10),
      );

      await manager.connect((gen) async {});
      expect(manager.status, equals(ConnectionStatus.connected));

      // Multiple rapid buffer events
      manager.onBufferingState(true, timeout: const Duration(milliseconds: 20));
      manager.onBufferingState(true, timeout: const Duration(milliseconds: 20));
      manager.onBufferingState(true, timeout: const Duration(milliseconds: 20));

      // Wait for buffer timeout
      await Future.delayed(const Duration(milliseconds: 50));

      // Should enter reconnecting exactly once
      expect(manager.status, equals(ConnectionStatus.reconnecting));
      expect(manager.retryCount, equals(1));

      manager.dispose();
    });

    test('Teste 10: Retry manual durante retry automático não cria concorrência', () async {
      final manager = PlayerConnectionManager(
        maxRetries: 3,
        baseBackoff: const Duration(milliseconds: 100),
      );

      int attempts = 0;
      await manager.connect((gen) async {
        attempts++;
        if (attempts == 1) {
          throw Exception('Fail attempt 1');
        }
      });

      expect(manager.status, equals(ConnectionStatus.reconnecting));
      expect(attempts, equals(1));

      // User taps "Retry" manually before backoff timer elapses
      await manager.retryManual();

      expect(attempts, equals(2));
      expect(manager.status, equals(ConnectionStatus.connected));

      // Wait past original timer duration to ensure original timer didn't fire again
      await Future.delayed(const Duration(milliseconds: 150));
      expect(attempts, equals(2));

      manager.dispose();
    });
  });
}
