import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/models/epg_program.dart';
import 'package:best_player/services/epg_service.dart';

void main() {
  group('EpgService and EpgProgram Tests', () {
    test('EpgProgram isCurrentlyAiring and progress calculation', () {
      final now = DateTime.now();
      final program = EpgProgram(
        id: '1',
        channelId: 'ch1',
        title: 'Jornal Nacional',
        description: 'Notícias do dia',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 30)),
      );

      expect(program.isCurrentlyAiring, isTrue);
      expect(program.progress, greaterThanOrEqualTo(0.4));
      expect(program.progress, lessThanOrEqualTo(0.6));
    });

    test('EpgService caches and returns null when not found', () {
      final service = EpgService();
      expect(service.getCurrentProgram('non_existent'), isNull);
      expect(service.getNextProgram('non_existent'), isNull);
    });
  });
}
