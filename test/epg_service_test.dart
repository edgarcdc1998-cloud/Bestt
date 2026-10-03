import 'package:flutter_test/flutter_test.dart';
import 'package:best_player/models/epg_program.dart';
import 'package:best_player/services/epg_service.dart';

void main() {
  group('EpgService and EpgProgram Tests', () {
    test('1. EpgProgram isCurrentlyAiring and progress calculation', () {
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

    test('2. EpgService caches and returns null when not found', () {
      final service = EpgService();
      expect(service.getCurrentProgram('non_existent'), isNull);
      expect(service.getNextProgram('non_existent'), isNull);
    });

    test('3. parseXmlTvDate parses XMLTV format with timezone offset', () {
      final dt = EpgService.parseXmlTvDate('20261003120000 +0000');
      expect(dt, isNotNull);
      expect(dt!.toUtc().year, equals(2026));
      expect(dt.toUtc().month, equals(10));
      expect(dt.toUtc().day, equals(3));
      expect(dt.toUtc().hour, equals(12));
      expect(dt.toUtc().minute, equals(0));
    });

    test('4. parseXmlTv parses XMLTV xml content and indexes programs', () {
      final service = EpgService();
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="20261003100000 +0000" stop="20261003110000 +0000" channel="globo.br">
    <title lang="pt">Bom Dia Brasil</title>
    <desc lang="pt">Telejornal matutino &amp; notícias</desc>
  </programme>
  <programme start="20261003110000 +0000" stop="20261003120000 +0000" channel="globo.br">
    <title lang="pt">Encontro</title>
    <desc lang="pt">Programa de variedades</desc>
  </programme>
  <programme start="20261003100000 +0000" stop="20261003120000 +0000" channel="sbt.br">
    <title lang="pt">Primeiro Impacto</title>
  </programme>
</tv>''';

      final result = service.parseXmlTv(xml);
      expect(result.containsKey('globo.br'), isTrue);
      expect(result['globo.br']!.length, equals(2));
      expect(result['globo.br']![0].title, equals('Bom Dia Brasil'));
      expect(result['globo.br']![0].description, equals('Telejornal matutino & notícias'));
      expect(result['globo.br']![1].title, equals('Encontro'));

      final sbtList = service.getProgramsForChannel('sbt.br');
      expect(sbtList.length, equals(1));
      expect(sbtList[0].title, equals('Primeiro Impacto'));
    });
  });
}
