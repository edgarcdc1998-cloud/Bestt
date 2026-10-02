import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/playback_position_debouncer.dart';

void main() {
  group('PlaybackPositionDebouncer Tests (ETAPA 3)', () {
    test('1. Atualização de posição não grava imediatamente no storage', () async {
      int persistCallCount = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 50),
        onPersist: (map) async {
          persistCallCount++;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 10), inMemoryMap);

      // Memory cache is updated immediately
      expect(inMemoryMap['vod_1'], equals(const Duration(seconds: 10)));
      // Storage persist callback was NOT called immediately
      expect(persistCallCount, equals(0));
      expect(debouncer.hasPendingWrite, isTrue);

      debouncer.cancel();
    });

    test('2. Múltiplas atualizações rápidas resultam em apenas uma persistência', () async {
      int persistCallCount = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 40),
        onPersist: (map) async {
          persistCallCount++;
        },
      );

      // 10 rapid position ticks (simulating 10 ticks/sec from player)
      for (int i = 5; i <= 15; i++) {
        debouncer.recordPosition('vod_1', Duration(seconds: i), inMemoryMap);
      }

      expect(persistCallCount, equals(0));

      // Wait for debounce interval to elapse
      await Future.delayed(const Duration(milliseconds: 60));

      expect(persistCallCount, equals(1));
      expect(debouncer.hasPendingWrite, isFalse);

      debouncer.cancel();
    });

    test('3. Somente a posição mais recente é persistida após o debounce', () async {
      Map<String, Duration> persistedSnapshot = {};
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 30),
        onPersist: (map) async {
          persistedSnapshot = map;
        },
      );

      debouncer.recordPosition('vod_movie', const Duration(seconds: 10), inMemoryMap);
      debouncer.recordPosition('vod_movie', const Duration(seconds: 20), inMemoryMap);
      debouncer.recordPosition('vod_movie', const Duration(seconds: 35), inMemoryMap);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(persistedSnapshot['vod_movie'], equals(const Duration(seconds: 35)));

      debouncer.cancel();
    });

    test('4. Novo update reinicia o timer do debounce corretamente', () async {
      int persistCallCount = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 40),
        onPersist: (map) async {
          persistCallCount++;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 10), inMemoryMap);
      await Future.delayed(const Duration(milliseconds: 25)); // 25ms < 40ms

      // New update resets the 40ms timer
      debouncer.recordPosition('vod_1', const Duration(seconds: 12), inMemoryMap);
      await Future.delayed(const Duration(milliseconds: 25)); // another 25ms (total 50ms from start)

      // Should not have persisted yet because timer was reset
      expect(persistCallCount, equals(0));

      // Now wait until second timer expires
      await Future.delayed(const Duration(milliseconds: 25));
      expect(persistCallCount, equals(1));

      debouncer.cancel();
    });

    test('5. Cancelamento do timer impede a gravação', () async {
      int persistCallCount = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 40),
        onPersist: (map) async {
          persistCallCount++;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 10), inMemoryMap);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 60));

      expect(persistCallCount, equals(0));
      expect(debouncer.hasPendingWrite, isFalse);
    });

    test('6. Flush final persiste a última posição imediatamente sem esperar o timer', () async {
      Map<String, Duration> persistedSnapshot = {};
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(seconds: 5), // Long 5s timer
        onPersist: (map) async {
          persistedSnapshot = map;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 120), inMemoryMap);
      expect(persistedSnapshot, isEmpty);

      // Force immediate flush (e.g. user pauses or leaves screen)
      await debouncer.flush(inMemoryMap);

      expect(persistedSnapshot['vod_1'], equals(const Duration(seconds: 120)));
      expect(debouncer.hasPendingWrite, isFalse);

      debouncer.cancel();
    });

    test('7. Posição inválida (negativa, zero, < 5s, absurda) não é persistida', () async {
      int persistCallCount = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 20),
        onPersist: (map) async {
          persistCallCount++;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 2), inMemoryMap); // < 5s
      debouncer.recordPosition('vod_1', const Duration(seconds: -10), inMemoryMap); // Negative
      debouncer.recordPosition('vod_1', const Duration(hours: 500), inMemoryMap); // Out of bounds
      debouncer.recordPosition('', const Duration(seconds: 15), inMemoryMap); // Empty media ID

      await Future.delayed(const Duration(milliseconds: 40));

      expect(persistCallCount, equals(0));
      expect(inMemoryMap, isEmpty);

      debouncer.cancel();
    });

    test('8. Posição de conteúdo antigo não é misturada com conteúdo novo', () async {
      Map<String, Duration> persistedSnapshot = {};
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 30),
        onPersist: (map) async {
          persistedSnapshot = map;
        },
      );

      debouncer.recordPosition('movie_A', const Duration(minutes: 15), inMemoryMap);
      debouncer.recordPosition('movie_B', const Duration(minutes: 45), inMemoryMap);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(persistedSnapshot['movie_A'], equals(const Duration(minutes: 15)));
      expect(persistedSnapshot['movie_B'], equals(const Duration(minutes: 45)));

      debouncer.cancel();
    });

    test('9. Gravações persistentes são protegidas contra concorrência', () async {
      int concurrencyCount = 0;
      int maxConcurrency = 0;
      int totalPersists = 0;
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 10),
        onPersist: (map) async {
          concurrencyCount++;
          if (concurrencyCount > maxConcurrency) {
            maxConcurrency = concurrencyCount;
          }
          await Future.delayed(const Duration(milliseconds: 30));
          concurrencyCount--;
          totalPersists++;
        },
      );

      debouncer.recordPosition('vod_1', const Duration(seconds: 10), inMemoryMap);
      await debouncer.flush(inMemoryMap);
      // Immediate second flush while first might be busy
      await debouncer.flush(inMemoryMap);

      expect(maxConcurrency, equals(1)); // Never > 1 concurrent write
      expect(totalPersists, greaterThanOrEqualTo(1));

      debouncer.cancel();
    });

    test('10. Dispose trata e persiste corretamente posição pendente', () async {
      Map<String, Duration> persistedSnapshot = {};
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(seconds: 10),
        onPersist: (map) async {
          persistedSnapshot = map;
        },
      );

      debouncer.recordPosition('vod_ep1', const Duration(minutes: 22), inMemoryMap);
      expect(persistedSnapshot, isEmpty);

      await debouncer.dispose(inMemoryMap);

      expect(debouncer.isDisposed, isTrue);
      expect(persistedSnapshot['vod_ep1'], equals(const Duration(minutes: 22)));
    });
  });
}
