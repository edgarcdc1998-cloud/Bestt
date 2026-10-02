import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/services/playback_position_debouncer.dart';

void main() {
  group('PlaybackPositionDebouncer Tests (ETAPA 3.1 Auditoria)', () {
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

      // 10 rapid position ticks
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

    test('3. Nova posição durante persistência em andamento é persistida (loop de dreno)', () async {
      final persistedSnapshots = <Map<String, Duration>>[];
      final inMemoryMap = <String, Duration>{};
      final slowPersistCompleter = Completer<void>();

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 20),
        onPersist: (map) async {
          persistedSnapshots.add(Map.from(map));
          if (persistedSnapshots.length == 1) {
            // First persist takes time
            await slowPersistCompleter.future;
          }
        },
      );

      // Record position 1
      debouncer.recordPosition('vod_movie', const Duration(seconds: 10), inMemoryMap);

      // Wait for first persist to trigger
      await Future.delayed(const Duration(milliseconds: 30));
      expect(persistedSnapshots.length, equals(1));
      expect(persistedSnapshots.first['vod_movie'], equals(const Duration(seconds: 10)));
      expect(debouncer.isPersisting, isTrue);

      // Record a new position while first persist is still in flight
      debouncer.recordPosition('vod_movie', const Duration(seconds: 35), inMemoryMap);
      expect(debouncer.hasPendingWrite, isTrue);

      // Complete the first slow persist
      slowPersistCompleter.complete();
      await Future.delayed(const Duration(milliseconds: 30));

      // The loop must have automatically picked up the newer position and persisted it
      expect(persistedSnapshots.length, equals(2));
      expect(persistedSnapshots.last['vod_movie'], equals(const Duration(seconds: 35)));
      expect(debouncer.hasPendingWrite, isFalse);

      debouncer.cancel();
    });

    test('4. Flush durante persistência em andamento aguarda e grava a posição mais recente', () async {
      final persistedSnapshots = <Map<String, Duration>>[];
      final inMemoryMap = <String, Duration>{};
      final slowPersistCompleter = Completer<void>();

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 20),
        onPersist: (map) async {
          persistedSnapshots.add(Map.from(map));
          if (persistedSnapshots.length == 1) {
            await slowPersistCompleter.future;
          }
        },
      );

      // Trigger first write
      debouncer.recordPosition('vod_A', const Duration(seconds: 10), inMemoryMap);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(debouncer.isPersisting, isTrue);

      // New position arrives
      debouncer.recordPosition('vod_A', const Duration(seconds: 50), inMemoryMap);

      // Release first write and flush
      slowPersistCompleter.complete();
      await debouncer.flush(inMemoryMap);

      expect(persistedSnapshots.last['vod_A'], equals(const Duration(seconds: 50)));

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

    test('6. Posição inválida (<5s, negativa, >100h) é ignorada sem poluir o mapa', () async {
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
      debouncer.recordPosition('vod_1', const Duration(hours: 500), inMemoryMap); // > 100h
      debouncer.recordPosition('', const Duration(seconds: 15), inMemoryMap); // Empty media ID

      await Future.delayed(const Duration(milliseconds: 40));

      expect(persistCallCount, equals(0));
      expect(inMemoryMap, isEmpty);

      debouncer.cancel();
    });

    test('7. Troca de conteúdo: posições de VOD A e VOD B permanecem estritamente isoladas', () async {
      Map<String, Duration> persistedSnapshot = {};
      final inMemoryMap = <String, Duration>{};

      final debouncer = PlaybackPositionDebouncer(
        interval: const Duration(milliseconds: 30),
        onPersist: (map) async {
          persistedSnapshot = map;
        },
      );

      debouncer.recordPosition('movie_A', const Duration(seconds: 100), inMemoryMap);
      debouncer.recordPosition('movie_B', const Duration(seconds: 20), inMemoryMap);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(persistedSnapshot['movie_A'], equals(const Duration(seconds: 100)));
      expect(persistedSnapshot['movie_B'], equals(const Duration(seconds: 20)));

      debouncer.cancel();
    });

    test('8. Dispose trata e persiste corretamente posição pendente sem deixar resíduos', () async {
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
